package com.example.bill_manager

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.bill_manager/alarm"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val timeInMillis = call.argument<Long>("time")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val notificationId = call.argument<Int>("notificationId")
                    
                    if (timeInMillis != null && title != null && body != null && notificationId != null) {
                        scheduleAlarm(timeInMillis, title, body, notificationId)
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
    }
    
    private fun scheduleAlarm(timeInMillis: Long, title: String, body: String, notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("notificationId", notificationId)
            putExtra("billId", "bill_$notificationId") // Store billId for later use
        }
        
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
