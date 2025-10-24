# How Your App Sends Notifications

## Current Notification System Architecture

Your app uses a **DUAL NOTIFICATION SYSTEM** for maximum reliability:

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR APP                                  │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         NotificationService                         │    │
│  │  (Main coordinator)                                 │    │
│  └────────────────────────────────────────────────────┘    │
│           │                              │                   │
│           │                              │                   │
│           ▼                              ▼                   │
│  ┌──────────────────────┐    ┌──────────────────────┐      │
│  │ flutter_local_       │    │ AlarmNotification    │      │
│  │ notifications        │    │ Service              │      │
│  │                      │    │                      │      │
│  │ • Immediate          │    │ • Scheduled          │      │
│  │   notifications      │    │   notifications      │      │
│  │ • In-app display     │    │ • Background         │      │
│  └──────────────────────┘    └──────────────────────┘      │
│           │                              │                   │
└───────────┼──────────────────────────────┼───────────────────┘
            │                              │
            ▼                              ▼
┌───────────────────────┐    ┌──────────────────────────────┐
│ Flutter Local         │    │ Android AlarmManager         │
│ Notifications Plugin  │    │ (System Service)             │
│                       │    │                              │
│ • Shows notification  │    │ • Schedules exact alarms     │
│ • Handles taps        │    │ • Wakes device               │
│ • Manages channels    │    │ • Survives reboot            │
└───────────────────────┘    └──────────────────────────────┘
            │                              │
            └──────────────┬───────────────┘
                           ▼
                ┌──────────────────────┐
                │  Android System      │
                │  Notification Shade  │
                │                      │
                │  User sees           │
                │  notification here   │
                └──────────────────────┘
```

## Two Systems Working Together

### System 1: Flutter Local Notifications
**Package:** `flutter_local_notifications: ^18.0.1`

**Used For:**
- ✅ Immediate notifications (show right now)
- ✅ Test notifications
- ✅ Displaying the actual notification UI
- ✅ Handling notification taps

**How It Works:**
```dart
// Example: Immediate notification
await NotificationService().showImmediateNotification(
  'Bill Reminder',
  'Your electric bill is due tomorrow!',
);
```

**Limitations:**
- ❌ Unreliable when app is closed
- ❌ Can be killed by battery optimization
- ❌ Lost after phone reboot

### System 2: Android Alarm Manager Plus
**Package:** `android_alarm_manager_plus: ^4.0.3`

**Used For:**
- ✅ Scheduling future notifications
- ✅ Running code when app is closed
- ✅ Waking device at exact time
- ✅ Surviving phone reboots

**How It Works:**
```dart
// Example: Schedule notification for 10 seconds
await AndroidAlarmManager.oneShotAt(
  DateTime.now().add(Duration(seconds: 10)),
  999999, // Alarm ID
  testAlarmCallback, // Function to run
  exact: true,
  wakeup: true,
);
```

**Advantages:**
- ✅ Works when app is completely closed
- ✅ Uses system-level alarms (like alarm clock)
- ✅ Automatically reschedules after reboot
- ✅ Not affected by battery optimization

## Complete Flow: How a Bill Notification Works

### Step 1: User Adds a Bill
```
User adds bill → BillProvider.addBill() → scheduleBillNotification()
```

### Step 2: Notification Gets Scheduled
```dart
// In NotificationService
await AlarmNotificationService().scheduleBillNotification(
  bill,
  daysBeforeDue: 1,  // Notify 1 day before
  notificationHour: 9,  // At 9 AM
  notificationMinute: 0,
);
```

### Step 3: Alarm Manager Registers the Alarm
```
AlarmNotificationService → AndroidAlarmManager.oneShotAt()
→ Android System registers alarm
```

### Step 4: At Scheduled Time (Even if App is Closed)
```
Android System → Triggers alarm → Wakes device
→ Runs alarmCallback() in background isolate
```

### Step 5: Background Callback Executes
```dart
@pragma('vm:entry-point')
void alarmCallback() async {
  // 1. Initialize Hive (access database)
  await Hive.initFlutter();
  
  // 2. Open bills database
  final billsBox = await Hive.openBox<BillHive>('bills');
  
  // 3. Check which bills need notifications
  for (var bill in billsBox.values) {
    if (bill is due today/tomorrow/in 7 days) {
      // 4. Show notification using flutter_local_notifications
      await notifications.show(...);
      
      // 5. Save to notification history
      await historyBox.put(...);
    }
  }
}
```

### Step 6: User Sees Notification
```
Notification appears in notification shade
User can tap to open app
Notification is saved in history
```

## What Packages Are Being Used

### 1. flutter_local_notifications (v18.0.1)
**Purpose:** Display notifications
**Location:** `pubspec.yaml`
```yaml
flutter_local_notifications: ^18.0.1
```

**Key Features:**
- Creates notification channels
- Shows notifications with custom icons, sounds, vibration
- Handles notification taps
- Manages notification permissions

### 2. android_alarm_manager_plus (v4.0.3)
**Purpose:** Schedule reliable alarms
**Location:** `pubspec.yaml`
```yaml
android_alarm_manager_plus: ^4.0.3
```

**Key Features:**
- Schedules exact-time alarms
- Runs callbacks in background
- Wakes device when needed
- Survives app closure and reboots

### 3. timezone (v0.9.4)
**Purpose:** Handle time zones correctly
**Location:** `pubspec.yaml`
```yaml
timezone: ^0.9.4
```

**Key Features:**
- Converts times to local timezone
- Handles daylight saving time
- Ensures notifications fire at correct local time

## Notification Types in Your App

### 1. Immediate Notifications
**Trigger:** User action (e.g., "Test Notification" button)
**System Used:** flutter_local_notifications only
**Example:**
```dart
await NotificationService().showImmediateNotification(
  'Test',
  'This shows immediately!',
);
```

### 2. Scheduled Notifications (Test)
**Trigger:** "Test Alarm Notification" button
**System Used:** android_alarm_manager_plus + flutter_local_notifications
**Flow:**
1. Schedule alarm for 10 seconds
2. Close app
3. Alarm triggers after 10 seconds
4. Callback shows notification

### 3. Bill Notifications
**Trigger:** Bill due date approaching
**System Used:** android_alarm_manager_plus + flutter_local_notifications
**Schedule:**
- 7 days before due date (at 9 AM)
- 1 day before due date (at 9 AM)
- On due date (at 9 AM)

### 4. Daily Check
**Trigger:** Every day at 9 AM
**System Used:** android_alarm_manager_plus
**Purpose:** Check all bills and send notifications for any that are due

## Permissions Required

### Android Manifest Permissions
```xml
<!-- Show notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Schedule exact alarms (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

<!-- Wake device for notifications -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- Reschedule after reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Background service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## Why This Dual System?

### Problem with Single System
If we only used `flutter_local_notifications`:
- ❌ Notifications might not fire when app is closed
- ❌ Lost after phone reboot
- ❌ Unreliable on some Android versions

### Solution: Dual System
By combining both systems:
- ✅ Alarm Manager guarantees the callback runs
- ✅ Local Notifications displays the notification
- ✅ Works even when app is closed
- ✅ Survives phone reboots
- ✅ Reliable like alarm clock apps

## Summary

**Your app uses:**
1. **android_alarm_manager_plus** - To schedule reliable alarms that work when app is closed
2. **flutter_local_notifications** - To display the actual notifications
3. **timezone** - To handle time zones correctly

**The flow is:**
```
Schedule Alarm → Android AlarmManager → Triggers at Time
→ Runs Background Callback → Shows Notification → Saves to History
```

This is the same reliable system used by alarm clock apps, calendar apps, and messaging apps! 🎉
