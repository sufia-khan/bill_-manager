package com.example.bill_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.AlarmManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Bill Reminder"
        var body = intent.getStringExtra("body") ?: "You have a bill due soon"
        val notificationId = intent.getIntExtra("notificationId", 0)
        val billId = intent.getStringExtra("billId") ?: ""
        val notificationUserId = intent.getStringExtra("userId") ?: ""
        
        // Recurring bill info
        val isRecurring = intent.getBooleanExtra("isRecurring", false)
        val recurringType = intent.getStringExtra("recurringType") ?: ""
        val billTitle = intent.getStringExtra("billTitle") ?: ""
        val billAmount = intent.getDoubleExtra("billAmount", 0.0)
        val billVendor = intent.getStringExtra("billVendor") ?: ""
        val currentSequence = intent.getIntExtra("currentSequence", 1)
        val repeatCount = intent.getIntExtra("repeatCount", -1)
        
        Log.d("AlarmReceiver", "Notification triggered: $title")
        Log.d("AlarmReceiver", "Bill ID: $billId, isRecurring: $isRecurring, type: $recurringType, seq: $currentSequence/$repeatCount")
        
        // Get current logged-in user
        val currentUserId = getCurrentUserId(context)
        Log.d("AlarmReceiver", "Current logged-in user: $currentUserId, Notification for user: $notificationUserId")
        
        // For recurring bills, create unique billId with sequence and add sequence to body
        var uniqueBillId = billId
        var displayBody = body
        if (isRecurring && repeatCount > 0) {
            uniqueBillId = "${billId}_seq_$currentSequence"
            displayBody = "$body ($currentSequence of $repeatCount)"
        } else if (isRecurring) {
            uniqueBillId = "${billId}_seq_$currentSequence"
            displayBody = "$body (#$currentSequence)"
        }
        
        // CRITICAL: Only save to history if notification belongs to a valid user
        // This prevents orphan notifications when user logs out
        if (notificationUserId.isNotEmpty()) {
            saveToHistory(context, title, displayBody, uniqueBillId, notificationUserId)
        }
        
        // CRITICAL: Only schedule next recurring instance if:
        // 1. The notification user matches the currently logged-in user
        // 2. A user is actually logged in
        // This prevents ghost notifications from accumulating after logout
        if (isRecurring && recurringType.isNotEmpty()) {
            if (currentUserId.isEmpty()) {
                Log.d("AlarmReceiver", "No user logged in - NOT scheduling next recurring instance")
            } else if (notificationUserId.isEmpty() || notificationUserId == currentUserId) {
                scheduleNextRecurringInstance(
                    context, billId, billTitle, billAmount, billVendor,
                    notificationUserId, recurringType, currentSequence, repeatCount
                )
            } else {
                Log.d("AlarmReceiver", "User mismatch - NOT scheduling next recurring instance (notification: $notificationUserId, current: $currentUserId)")
            }
        }
        
        // Check if should show notification on device
        val shouldShowNotification = when {
            notificationUserId.isEmpty() -> true  // Legacy notification without userId
            currentUserId.isEmpty() -> false      // No user logged in - don't show
            notificationUserId != currentUserId -> false  // Wrong user - don't show
            else -> true
        }
        
        if (!shouldShowNotification) {
            Log.d("AlarmReceiver", "Notification saved but not shown (no user or different user)")
            return
        }
        
        // CRITICAL FIX: Prevent duplicate notifications using billId + sequence
        val notificationKey = if (isRecurring) "${billId}_seq_$currentSequence" else billId
        if (isDuplicateNotification(context, notificationKey)) {
            Log.d("AlarmReceiver", "Skipping duplicate notification: $notificationKey")
            return
        }
        
        // Mark this notification as shown
        markNotificationShown(context, notificationKey)
        
        showNotification(context, title, displayBody, notificationId, billId)
    }
    
    private fun isDuplicateNotification(context: Context, notificationKey: String): Boolean {
        try {
            val prefs = context.getSharedPreferences("shown_notifications", Context.MODE_PRIVATE)
            val lastShownTime = prefs.getLong(notificationKey, 0)
            val now = System.currentTimeMillis()
            
            // Consider duplicate if shown within the last 30 seconds
            if (lastShownTime > 0 && now - lastShownTime < 30000) {
                return true
            }
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error checking duplicate: ${e.message}")
        }
        return false
    }
    
    private fun markNotificationShown(context: Context, notificationKey: String) {
        try {
            val prefs = context.getSharedPreferences("shown_notifications", Context.MODE_PRIVATE)
            prefs.edit().putLong(notificationKey, System.currentTimeMillis()).apply()
            
            // Clean up old entries (older than 5 minutes)
            val now = System.currentTimeMillis()
            val allEntries = prefs.all
            val editor = prefs.edit()
            for ((key, value) in allEntries) {
                if (value is Long && now - value > 300000) {
                    editor.remove(key)
                }
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error marking notification: ${e.message}")
        }
    }
    
    private fun scheduleNextRecurringInstance(
        context: Context,
        billId: String,
        billTitle: String,
        billAmount: Double,
        billVendor: String,
        userId: String,
        recurringType: String,
        currentSequence: Int,
        repeatCount: Int
    ) {
        // Check repeat count limit
        val nextSequence = currentSequence + 1
        if (repeatCount > 0 && nextSequence > repeatCount) {
            Log.d("AlarmReceiver", "Repeat count limit reached: $currentSequence/$repeatCount")
            return
        }
        
        // Calculate next due time
        val now = System.currentTimeMillis()
        val nextDueTime = when (recurringType.lowercase()) {
            "1 minute (testing)" -> now + 60 * 1000 // 1 minute
            "weekly" -> now + 7 * 24 * 60 * 60 * 1000L // 7 days
            "monthly" -> now + 30 * 24 * 60 * 60 * 1000L // ~30 days
            "quarterly" -> now + 90 * 24 * 60 * 60 * 1000L // ~90 days
            "yearly" -> now + 365 * 24 * 60 * 60 * 1000L // ~365 days
            else -> return
        }
        
        // Generate new notification ID for next instance
        val nextNotificationId = (billId + nextSequence.toString()).hashCode()
        
        // Create notification title and body - matches notification screen format
        val nextTitle = "$billTitle Overdue"
        val nextBody = "$billTitle of \$${"%.0f".format(billAmount)} is overdue"
        
        Log.d("AlarmReceiver", "Scheduling next recurring instance: seq=$nextSequence, time=$nextDueTime")
        
        // Schedule the alarm
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("title", nextTitle)
            putExtra("body", nextBody)
            putExtra("notificationId", nextNotificationId)
            putExtra("billId", billId)
            putExtra("userId", userId)
            putExtra("isRecurring", true)
            putExtra("recurringType", recurringType)
            putExtra("billTitle", billTitle)
            putExtra("billAmount", billAmount)
            putExtra("billVendor", billVendor)
            putExtra("currentSequence", nextSequence)
            putExtra("repeatCount", repeatCount)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            nextNotificationId,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            // CRITICAL: Use setAlarmClock for highest reliability on Android 12+
            // AlarmClock alarms are exempt from battery restrictions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val showIntent = PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(nextDueTime, showIntent),
                    pendingIntent
                )
                Log.d("AlarmReceiver", "✅ Used setAlarmClock (highest reliability)")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextDueTime,
                    pendingIntent
                )
                Log.d("AlarmReceiver", "✅ Used setExactAndAllowWhileIdle")
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    nextDueTime,
                    pendingIntent
                )
            }
            Log.d("AlarmReceiver", "✅ Next recurring alarm scheduled for ${java.util.Date(nextDueTime)}")
            
            // Save pending recurring bill info for Flutter to pick up
            savePendingRecurringBill(context, billId, billTitle, billAmount, billVendor, 
                userId, recurringType, nextSequence, repeatCount, nextDueTime)
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "❌ Failed to schedule next alarm: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun savePendingRecurringBill(
        context: Context,
        billId: String,
        billTitle: String,
        billAmount: Double,
        billVendor: String,
        userId: String,
        recurringType: String,
        sequence: Int,
        repeatCount: Int,
        dueTime: Long
    ) {
        try {
            val prefs = context.getSharedPreferences("pending_recurring_bills", Context.MODE_PRIVATE)
            val existingData = prefs.getString("bills", "[]") ?: "[]"
            
            val billData = """{"billId":"$billId","title":"$billTitle","amount":$billAmount,"vendor":"$billVendor","userId":"$userId","recurringType":"$recurringType","sequence":$sequence,"repeatCount":$repeatCount,"dueTime":$dueTime}"""
            
            val newData = if (existingData == "[]") {
                "[$billData]"
            } else {
                existingData.dropLast(1) + ",$billData]"
            }
            
            prefs.edit().putString("bills", newData).apply()
            Log.d("AlarmReceiver", "Saved pending recurring bill: $billTitle seq=$sequence")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error saving pending recurring bill: ${e.message}")
        }
    }
    
    private fun showNotification(context: Context, title: String, body: String, notificationId: Int, billId: String?) {
        // Create notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "bill_reminders",
                "Bill Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for upcoming bill payments"
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        
        // Create intent to open app when notification is tapped
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("billId", billId)
            putExtra("fromNotification", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, "bill_reminders")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(pendingIntent)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
        Log.d("AlarmReceiver", "Notification shown on device")
    }
    
    private fun getCurrentUserId(context: Context): String {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            return prefs.getString("flutter.currentUserId", "") ?: ""
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error getting current user ID: ${e.message}")
            return ""
        }
    }
    
    private fun saveToHistory(context: Context, title: String, body: String, billId: String?, userId: String) {
        try {
            val prefs = context.getSharedPreferences("notification_history", Context.MODE_PRIVATE)
            val timestamp = System.currentTimeMillis()
            
            val escapedTitle = title.replace("\"", "\\\"").replace("\n", "\\n")
            val escapedBody = body.replace("\"", "\\\"").replace("\n", "\\n")
            
            val notificationData = """{"title":"$escapedTitle","body":"$escapedBody","billId":"${billId ?: ""}","userId":"$userId","timestamp":$timestamp}"""
            
            val existingData = prefs.getString("pending_notifications", "[]") ?: "[]"
            
            // Simple duplicate check - just look for same timestamp within 5 seconds
            // No complex regex - just check if any recent notification exists
            val isDuplicate = try {
                if (existingData != "[]") {
                    // Extract all timestamps and check if any are within 5 seconds
                    val timestampPattern = """"timestamp":(\d+)""".toRegex()
                    val matches = timestampPattern.findAll(existingData)
                    matches.any { match ->
                        val existingTimestamp = match.groupValues[1].toLongOrNull() ?: 0L
                        val timeDiff = timestamp - existingTimestamp
                        // Only skip if VERY recent (within 3 seconds) - this catches true duplicates
                        // but allows 1-minute recurring bills
                        timeDiff in 0..3000
                    }
                } else false
            } catch (e: Exception) { 
                Log.d("AlarmReceiver", "Duplicate check error (allowing save): ${e.message}")
                false 
            }
            
            if (isDuplicate) {
                Log.d("AlarmReceiver", "Skipping duplicate notification (within 3 sec of existing)")
                return
            }
            
            val newData = if (existingData == "[]") {
                "[$notificationData]"
            } else {
                existingData.dropLast(1) + ",$notificationData]"
            }
            
            prefs.edit().putString("pending_notifications", newData).apply()
            Log.d("AlarmReceiver", "Saved notification to history: $title at $timestamp")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error saving to history: ${e.message}")
        }
    }
}
