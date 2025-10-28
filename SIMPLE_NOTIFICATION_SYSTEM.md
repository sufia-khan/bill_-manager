# Simple & Reliable Notification System

## Overview

Your app now uses a **simple, clean notification system** with only `flutter_local_notifications` - no complex alarm manager or background isolates needed!

## ✅ What You Get

- **Scheduled notifications** that work even when app is closed
- **Doze mode support** with `androidAllowWhileIdle: true`
- **Notification tap handling** - opens app and navigates to bill
- **Timezone support** - notifications fire at correct local time
- **Permission handling** for Android 13+ and iOS
- **Clean, modular code** - single `NotificationService` class

## 📦 Single Package Used

```yaml
flutter_local_notifications: ^18.0.1
timezone: ^0.9.4
```

That's it! No alarm manager, no background isolates, no complexity.

## 🎯 How It Works

### 1. Schedule a Bill Notification

```dart
await NotificationService().scheduleBillNotification(
  bill,
  daysBeforeDue: 1,  // Notify 1 day before
  notificationHour: 9,  // At 9 AM
  notificationMinute: 0,
);
```

### 2. System Schedules It

The notification is scheduled using `zonedSchedule()` with:
- `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`
- This ensures it works even in Doze mode
- Uses timezone for accurate local time

### 3. Notification Fires (Even if App is Closed!)

At the scheduled time:
- Android/iOS wakes up and shows the notification
- Works even if app is completely closed
- Works even if phone is in Doze mode

### 4. User Taps Notification

- App opens automatically
- Navigates to the bill details screen
- Uses the bill ID passed in the payload

## 🔧 Key Features

### Doze Mode Support

```dart
androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle
```

This is the magic setting that makes notifications work reliably:
- **exactAllowWhileIdle** = Notification fires even in Doze mode
- No need for alarm manager
- Built into flutter_local_notifications

### Timezone Handling

```dart
final scheduledTime = tz.TZDateTime(
  tz.local,
  notificationDate.year,
  notificationDate.month,
  notificationDate.day,
  9, // hour
  0, // minute
);
```

Automatically handles:
- Local timezone
- Daylight saving time
- Different time zones

### Unique Notification IDs

```dart
bill.id.hashCode  // Each bill gets unique ID
```

This ensures:
- Multiple notifications don't overwrite each other
- Can cancel specific bill notifications
- Can reschedule individual bills

### Notification Tap Navigation

```dart
NotificationService.onNotificationTapped = (String? billId) {
  if (billId != null) {
    MyApp.navigatorKey.currentState?.pushNamed(
      '/bill-details',
      arguments: billId,
    );
  }
};
```

When user taps notification:
- App opens
- Navigates to bill details
- Shows the specific bill

## 📱 Permissions

### Android (Automatic)

```xml
<!-- Show notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Schedule exact alarms (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

<!-- Reschedule after reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

The app automatically requests these at runtime.

### iOS (Automatic)

Permissions requested on first notification:
- Alert
- Badge
- Sound

## 🧪 Testing

### Test Immediate Notification

```dart
await NotificationService().showImmediateNotification(
  'Test',
  'This shows immediately!',
);
```

### Test Scheduled Notification (10 seconds)

```dart
await NotificationService().scheduleTestNotification();
```

Then:
1. Close the app completely
2. Wait 10 seconds
3. Notification appears! 🎉

### Test Bill Notification

1. Add a bill due tomorrow
2. Close the app
3. At 9 AM tomorrow, notification appears

## 🔄 Reschedule After Reboot

When app starts, call:

```dart
await NotificationService().rescheduleAllNotifications(bills);
```

This reschedules all notifications after:
- Phone reboot
- App update
- App reinstall

## 📊 Debug & Monitor

### View Pending Notifications

```dart
final pending = await NotificationService().getPendingNotifications();
print('Pending: ${pending.length} notifications');
```

### Cancel Specific Notification

```dart
await NotificationService().cancelBillNotification(billId);
```

### Cancel All Notifications

```dart
await NotificationService().cancelAllNotifications();
```

## 🎨 Notification Appearance

### Android

- High priority (appears as heads-up)
- Sound + vibration
- LED lights
- Shows in notification shade
- Visible even in Do Not Disturb (if allowed)

### iOS

- Alert banner
- Sound
- Badge on app icon
- Shows in notification center

## 💡 Why This Works

### The Secret: `exactAllowWhileIdle`

This Android schedule mode:
- ✅ Works in Doze mode
- ✅ Works when app is closed
- ✅ Exact timing (not approximate)
- ✅ No background service needed
- ✅ No alarm manager needed

### System-Level Scheduling

When you call `zonedSchedule()`:
1. Flutter passes it to native Android/iOS
2. System schedules the notification
3. System guarantees delivery
4. No app code needs to run until notification fires

## 📝 Code Structure

```
lib/
├── services/
│   └── notification_service.dart  # Single service class
├── main.dart                      # Setup notification tap handler
└── screens/
    └── settings_screen.dart       # Test buttons
```

## 🚀 Usage Examples

### Schedule Bill Notification

```dart
// When adding a bill
await NotificationService().scheduleBillNotification(
  bill,
  daysBeforeDue: 1,
  notificationHour: 9,
  notificationMinute: 0,
);
```

### Show Immediate Notification

```dart
// For instant alerts
await NotificationService().showImmediateNotification(
  'Payment Received',
  'Your bill payment was successful!',
);
```

### Reschedule All (After Reboot)

```dart
// In BillProvider.initialize()
final bills = await getAllBills();
await NotificationService().rescheduleAllNotifications(bills);
```

## ⚙️ Configuration

### Notification Channel (Android)

```dart
const androidChannel = AndroidNotificationChannel(
  'bill_reminders',
  'Bill Reminders',
  description: 'Notifications for upcoming bill payments',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);
```

### Notification Details

```dart
const androidDetails = AndroidNotificationDetails(
  'bill_reminders',
  'Bill Reminders',
  importance: Importance.max,
  priority: Priority.high,
  playSound: true,
  enableVibration: true,
  enableLights: true,
);
```

## 🎯 Best Practices

### 1. Always Use Unique IDs

```dart
bill.id.hashCode  // ✅ Good
DateTime.now().millisecondsSinceEpoch  // ❌ Bad (can collide)
```

### 2. Check Permissions First

```dart
final enabled = await NotificationService().areNotificationsEnabled();
if (!enabled) {
  await NotificationService().requestPermissions();
}
```

### 3. Cancel Before Rescheduling

```dart
await NotificationService().cancelBillNotification(bill.id);
await NotificationService().scheduleBillNotification(bill);
```

### 4. Use Timezone for Scheduling

```dart
tz.TZDateTime.now(tz.local)  // ✅ Good
DateTime.now()  // ❌ Bad (no timezone)
```

## 🔍 Troubleshooting

### Notification Doesn't Appear

**Check:**
1. Notification permission granted?
2. Exact alarm permission granted? (Android 12+)
3. Do Not Disturb mode off?
4. Notification channel not blocked?

**Debug:**
```dart
final pending = await NotificationService().getPendingNotifications();
print('Pending: $pending');
```

### Notification Appears Late

**Cause:** Android battery optimization

**Solution:**
- Settings > Apps > BillManager > Battery > Unrestricted

### Notification Doesn't Navigate

**Check:**
1. Navigator key set in MaterialApp?
2. Route exists?
3. Payload passed correctly?

## 📈 Performance

- **Memory:** Minimal (no background service)
- **Battery:** Negligible (system handles scheduling)
- **CPU:** Zero when app is closed
- **Storage:** Only notification data

## 🎉 Summary

You now have a **simple, reliable notification system** that:

✅ Works when app is closed
✅ Works in Doze mode  
✅ Handles timezones correctly
✅ Navigates on tap
✅ Requires only one package
✅ No complex setup
✅ Clean, maintainable code

**It just works!** 🚀

---

## Quick Start

1. **Schedule a notification:**
   ```dart
   await NotificationService().scheduleBillNotification(bill);
   ```

2. **Test it:**
   ```dart
   await NotificationService().scheduleTestNotification();
   ```

3. **Close the app and wait 10 seconds**

4. **Notification appears!** 🎉

That's it! Simple, reliable, and production-ready.
