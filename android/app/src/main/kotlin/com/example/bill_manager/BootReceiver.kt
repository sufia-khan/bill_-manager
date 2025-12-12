package com.example.bill_manager

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * BootReceiver - Handles device boot completion
 * 
 * This receiver is triggered when the device boots up.
 * It reschedules pending recurring bill alarms that were lost during reboot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device booted - rescheduling pending alarms")
            
            // Reschedule any pending recurring bill alarms
            reschedulePendingAlarms(context)
        }
    }
    
    private fun reschedulePendingAlarms(context: Context) {
        try {
            val prefs = context.getSharedPreferences("pending_recurring_bills", Context.MODE_PRIVATE)
            val pendingData = prefs.getString("bills", "[]") ?: "[]"
            
            if (pendingData == "[]") {
                Log.d("BootReceiver", "No pending recurring bills to reschedule")
                return
            }
            
            val bills = JSONArray(pendingData)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var rescheduledCount = 0
            
            for (i in 0 until bills.length()) {
                try {
                    val bill = bills.getJSONObject(i)
                    val billId = bill.getString("billId")
                    val title = bill.getString("title")
                    val amount = bill.getDouble("amount")
                    val vendor = bill.getString("vendor")
                    val userId = bill.optString("userId", "")
                    val recurringType = bill.getString("recurringType")
                    val sequence = bill.getInt("sequence")
                    val repeatCount = bill.getInt("repeatCount")
                    var dueTime = bill.getLong("dueTime")
                    
                    // CRITICAL FIX: If due time is in the past, do NOT reschedule
                    // Past-due bills should remain overdue, not be rescheduled to future
                    // The Flutter app will handle creating proper next instances for recurring bills
                    if (dueTime <= now) {
                        Log.d("BootReceiver", "Skipping past-due bill: $title (due: $dueTime, now: $now)")
                        continue
                    }
                    
                    val notificationId = (billId + sequence.toString()).hashCode()
                    val notificationTitle = "Bill Due Today"
                    val notificationBody = "$title - \$${"%.2f".format(amount)} due to $vendor"
                    
                    val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                        putExtra("title", notificationTitle)
                        putExtra("body", notificationBody)
                        putExtra("notificationId", notificationId)
                        putExtra("billId", billId)
                        putExtra("userId", userId)
                        putExtra("isRecurring", true)
                        putExtra("recurringType", recurringType)
                        putExtra("billTitle", title)
                        putExtra("billAmount", amount)
                        putExtra("billVendor", vendor)
                        putExtra("currentSequence", sequence)
                        putExtra("repeatCount", repeatCount)
                    }
                    
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        notificationId,
                        alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    
                    // CRITICAL: Use setAlarmClock for highest reliability on Android 12+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val showIntent = PendingIntent.getActivity(
                            context,
                            0,
                            Intent(context, MainActivity::class.java),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        alarmManager.setAlarmClock(
                            AlarmManager.AlarmClockInfo(dueTime, showIntent),
                            pendingIntent
                        )
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            dueTime,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.RTC_WAKEUP,
                            dueTime,
                            pendingIntent
                        )
                    }
                    
                    rescheduledCount++
                    Log.d("BootReceiver", "✅ Rescheduled alarm for $title at ${java.util.Date(dueTime)}")
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Error rescheduling alarm: ${e.message}")
                }
            }
            
            Log.d("BootReceiver", "✅ Rescheduled $rescheduledCount alarms after boot")
        } catch (e: Exception) {
            Log.e("BootReceiver", "Error in reschedulePendingAlarms: ${e.message}")
        }
    }
    
    private fun calculateNextDueTime(now: Long, recurringType: String): Long {
        return when (recurringType.lowercase()) {
            "1 minute (testing)" -> now + 60 * 1000
            "weekly" -> now + 7 * 24 * 60 * 60 * 1000L
            "monthly" -> now + 30 * 24 * 60 * 60 * 1000L
            "quarterly" -> now + 90 * 24 * 60 * 60 * 1000L
            "yearly" -> now + 365 * 24 * 60 * 60 * 1000L
            else -> now + 24 * 60 * 60 * 1000L // Default to 1 day
        }
    }
}
