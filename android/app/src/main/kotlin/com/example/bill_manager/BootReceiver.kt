package com.example.bill_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver - Handles device boot completion
 * 
 * This receiver is triggered when the device boots up.
 * It ensures that bill notifications are rescheduled after a reboot.
 * 
 * Note: Actual rescheduling happens when the user opens the app,
 * as we need the Flutter engine to be running to access Hive database.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BillManager", "Device booted - notifications will be rescheduled when app opens")
            
            // Note: We can't directly reschedule notifications here because:
            // 1. We need the Flutter engine to be running
            // 2. We need access to Hive database to get bill data
            // 3. The app handles rescheduling in BillProvider.initialize()
            //
            // The user just needs to open the app once after reboot,
            // and all notifications will be automatically rescheduled.
        }
    }
}
