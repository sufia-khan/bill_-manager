package com.example.bill_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Bill Reminder"
        val body = intent.getStringExtra("body") ?: "You have a bill due soon"
        val notificationId = intent.getIntExtra("notificationId", 0)
        val billId = intent.getStringExtra("billId")
        
        Log.d("AlarmReceiver", "Notification triggered: $title")
        
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
        
        // Build and show notification
        val notification = NotificationCompat.Builder(context, "bill_reminders")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(pendingIntent) // Open app when tapped
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
        
        // Save to notification history via MethodChannel
        saveToHistory(context, title, body, billId)
        
        Log.d("AlarmReceiver", "Notification shown and saved to history")
    }
    
    private fun saveToHistory(context: Context, title: String, body: String, billId: String?) {
        try {
            // Use SharedPreferences to store notification temporarily
            // The Flutter app will read this when it starts
            val prefs = context.getSharedPreferences("notification_history", Context.MODE_PRIVATE)
            val timestamp = System.currentTimeMillis()
            
            // Store as JSON-like string
            val notificationData = """
                {
                    "title": "$title",
                    "body": "$body",
                    "billId": "${billId ?: ""}",
                    "timestamp": $timestamp
                }
            """.trimIndent()
            
            // Add to list of pending notifications
            val existingData = prefs.getString("pending_notifications", "[]")
            val newData = if (existingData == "[]") {
                "[$notificationData]"
            } else {
                existingData!!.dropLast(1) + ",$notificationData]"
            }
            
            prefs.edit().putString("pending_notifications", newData).apply()
            Log.d("AlarmReceiver", "Saved to SharedPreferences: $notificationData")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error saving to history: ${e.message}")
        }
    }
}
