# Alarm-Based Notification System

## Overview
The app now uses **android_alarm_manager_plus** for reliable background notifications that work even when:
- The app is closed
- The phone is locked
- The phone is rebooted (alarms are rescheduled automatically)

## How It Works

### 1. Alarm Manager Service
- **Location**: `lib/services/alarm_notification_service.dart`
- Uses Android's AlarmManager API for precise scheduling
- Runs callbacks in background isolates
- Automatically reschedules after device reboot

### 2. Dual Notification System
The app now uses TWO notification systems working together:

#### A. Flutter Local Notifications (Original)
- For immediate notifications
- For in-app notification display
- Fallback for iOS

#### B. Alarm Manager (New - Android Only)
- For scheduled notifications
- Works when app is closed
- Survives phone restarts
- More reliable for future notifications

### 3. Key Features

#### Daily Check
- Runs every day at 9:00 AM
- Checks all bills and sends notifications for:
  - Bills due today
  - Bills due tomorrow
  - Bills due in 7 days

#### Per-Bill Scheduling
- Each bill gets its own alarm
- Scheduled based on notification settings
- Automatically cancelled when bill is paid/deleted

#### Test Functionality
- Test immediate notifications (works immediately)
- Test alarm notifications (10 seconds delay)
- View scheduled notifications

## Permissions Required

### AndroidManifest.xml
```xml
<!-- Exact alarms (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

<!-- Boot completed (reschedule after reboot) -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Wake lock (wake device for notifications) -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- Foreground service (Android 9+) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## Testing Instructions

### 1. Test Immediate Notification
1. Open Settings screen
2. Tap "Test Notification (Immediate)"
3. Should see notification instantly

### 2. Test Alarm Notification (Background)
1. Open Settings screen
2. Tap "Test Alarm Notification"
3. **Close the app completely** (swipe away from recent apps)
4. Wait 10 seconds
5. You should receive a notification even with app closed!

### 3. Test Bill Notification
1. Add a new bill with due date tomorrow
2. Set notification time to a few minutes in the future
3. Close the app
4. Wait for the scheduled time
5. You should receive the notification

### 4. Test After Reboot
1. Schedule a notification for 5 minutes in the future
2. Reboot your phone
3. Wait for the scheduled time
4. Notification should still arrive (alarms are rescheduled on boot)

## How Notifications Are Scheduled

### When Adding a Bill
```dart
// Automatically schedules alarm notification
await NotificationService().scheduleBillNotification(
  bill,
  daysBeforeDue: 1,  // Notify 1 day before
  notificationHour: 9,  // At 9 AM
  notificationMinute: 0,
);
```

### Behind the Scenes
1. **NotificationService** receives the request
2. Calls **AlarmNotificationService** to schedule alarm
3. Alarm is registered with Android's AlarmManager
4. At scheduled time, alarm triggers callback
5. Callback runs in background isolate
6. Notification is displayed via Flutter Local Notifications

## Troubleshooting

### Notifications Not Appearing

#### Check 1: App Permissions
```
Settings > Apps > BillManager > Notifications
- Ensure "Allow notifications" is ON
```

#### Check 2: Exact Alarms Permission (Android 12+)
```
Settings > Apps > BillManager > Alarms & reminders
- Ensure "Allow setting alarms and reminders" is ON
```

#### Check 3: Battery Optimization
```
Settings > Apps > BillManager > Battery
- Set to "Unrestricted" or "Optimized" (not "Restricted")
```

#### Check 4: Do Not Disturb
- Ensure Do Not Disturb is off or allows notifications

### Debug Logs
Check the console for these messages:
- `✅ Alarm manager initialized`
- `✅ Alarm scheduled for bill: [Bill Name]`
- `🔔 Alarm callback triggered!`
- `✅ Notification sent for bill: [Bill Name]`

### View Scheduled Notifications
1. Open Settings screen
2. Tap "View Scheduled Notifications"
3. See list of all pending notifications

## Technical Details

### Alarm IDs
- Daily check: ID = 0
- Bill notifications: ID = bill.id.hashCode
- Test notification: ID = 999999

### Callback Functions
Must be top-level functions with `@pragma('vm:entry-point')`:
- `alarmCallback()` - Main notification check
- `testAlarmCallback()` - Test notification

### Background Isolate
- Callbacks run in separate isolate
- Must initialize Hive and adapters
- Must initialize notification plugin
- Cannot access app state directly

## Advantages Over Previous System

### Old System (flutter_local_notifications only)
- ❌ Notifications might not fire when app is closed
- ❌ Unreliable on some Android versions
- ❌ Lost after phone reboot
- ❌ Affected by battery optimization

### New System (alarm_manager + local_notifications)
- ✅ Reliable even when app is closed
- ✅ Works on all Android versions
- ✅ Survives phone reboot
- ✅ Uses system alarms (like alarm clock apps)
- ✅ Wakes device if needed
- ✅ Not affected by battery optimization

## Future Improvements

1. **iOS Support**: Implement similar system using iOS background tasks
2. **Notification History**: Track which notifications were actually delivered
3. **Smart Scheduling**: Adjust notification times based on user behavior
4. **Batch Notifications**: Group multiple bills due on same day
5. **Snooze Feature**: Allow users to snooze notifications

## Code Structure

```
lib/
├── services/
│   ├── notification_service.dart          # Main notification service
│   ├── alarm_notification_service.dart    # NEW: Alarm-based scheduling
│   └── notification_history_service.dart  # Notification history
├── main.dart                              # Initialize alarm service
└── screens/
    └── settings_screen.dart               # Test buttons
```

## Dependencies

```yaml
dependencies:
  flutter_local_notifications: ^18.0.1  # Display notifications
  android_alarm_manager_plus: ^4.0.3    # Schedule alarms
  timezone: ^0.9.4                       # Timezone handling
```

## Summary

The new alarm-based notification system ensures your bill reminders are delivered reliably, even when the app is not running. This provides a user experience similar to other popular apps like alarm clocks, calendar reminders, and messaging apps.

**Key Takeaway**: Notifications will now work just like your phone's alarm clock - they'll go off at the scheduled time no matter what! 🔔
