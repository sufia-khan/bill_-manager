package com.example.bill_manager

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "com.example.bill_manager/alarm"
    private val PREFS_CHANNEL = "com.example.bill_manager/prefs"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Alarm scheduling channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val timeInMillis = call.argument<Long>("time")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val notificationId = call.argument<Int>("notificationId")
                    val userId = call.argument<String>("userId") ?: ""
                    val billId = call.argument<String>("billId") ?: ""
                    val isRecurring = call.argument<Boolean>("isRecurring") ?: false
                    val recurringType = call.argument<String>("recurringType") ?: ""
                    val billTitle = call.argument<String>("billTitle") ?: ""
                    val billAmount = call.argument<Double>("billAmount") ?: 0.0
                    val billVendor = call.argument<String>("billVendor") ?: ""
                    val currentSequence = call.argument<Int>("currentSequence") ?: 1
                    val repeatCount = call.argument<Int>("repeatCount") ?: -1
                    
                    if (timeInMillis != null && title != null && body != null && notificationId != null) {
                        scheduleAlarm(timeInMillis, title, body, notificationId, userId, billId,
                            isRecurring, recurringType, billTitle, billAmount, billVendor, currentSequence, repeatCount)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                    }
                }
                "cancelAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId")
                    if (notificationId != null) {
                        cancelAlarm(notificationId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing notificationId", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // SharedPreferences channel for reading pending notifications
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PREFS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingNotifications" -> {
                    val pendingData = getPendingNotifications()
                    Log.d("MainActivity", "getPendingNotifications: $pendingData")
                    result.success(pendingData)
                }
                "clearPendingNotifications" -> {
                    clearPendingNotifications()
                    result.success(true)
                }
                "getCurrentUserId" -> {
                    val userId = getCurrentUserId()
                    result.success(userId)
                }
                "getPendingRecurringBills" -> {
                    val pendingData = getPendingRecurringBills()
                    Log.d("MainActivity", "getPendingRecurringBills: $pendingData")
                    result.success(pendingData)
                }
                "clearPendingRecurringBills" -> {
                    clearPendingRecurringBills()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun getPendingNotifications(): String {
        val prefs = getSharedPreferences("notification_history", Context.MODE_PRIVATE)
        return prefs.getString("pending_notifications", "[]") ?: "[]"
    }
    
    private fun clearPendingNotifications() {
        val prefs = getSharedPreferences("notification_history", Context.MODE_PRIVATE)
        prefs.edit().putString("pending_notifications", "[]").apply()
        Log.d("MainActivity", "Cleared pending notifications")
    }
    
    private fun getCurrentUserId(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.currentUserId", "") ?: ""
    }
    
    private fun getPendingRecurringBills(): String {
        val prefs = getSharedPreferences("pending_recurring_bills", Context.MODE_PRIVATE)
        return prefs.getString("bills", "[]") ?: "[]"
    }
    
    private fun clearPendingRecurringBills() {
        val prefs = getSharedPreferences("pending_recurring_bills", Context.MODE_PRIVATE)
        prefs.edit().putString("bills", "[]").apply()
        Log.d("MainActivity", "Cleared pending recurring bills")
    }
    
    private fun scheduleAlarm(
        timeInMillis: Long, title: String, body: String, notificationId: Int, 
        userId: String, billId: String, isRecurring: Boolean = false, 
        recurringType: String = "", billTitle: String = "", billAmount: Double = 0.0,
        billVendor: String = "", currentSequence: Int = 1, repeatCount: Int = -1
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("notificationId", notificationId)
            putExtra("billId", billId)
            putExtra("userId", userId)
            putExtra("isRecurring", isRecurring)
            putExtra("recurringType", recurringType)
            putExtra("billTitle", billTitle)
            putExtra("billAmount", billAmount)
            putExtra("billVendor", billVendor)
            putExtra("currentSequence", currentSequence)
            putExtra("repeatCount", repeatCount)
        }
        
        Log.d("MainActivity", "Scheduling alarm: time=$timeInMillis, isRecurring=$isRecurring, type=$recurringType")
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use setExactAndAllowWhileIdle for reliable delivery
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                timeInMillis,
                pendingIntent
            )
        }
    }
    
    private fun cancelAlarm(notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }
}
