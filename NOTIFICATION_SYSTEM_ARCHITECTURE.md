# 📱 BillMinder Notification System Architecture

## Complete Guide to Bill Notifications (Recurring & Non-Recurring)

---

## 🎯 Overview

Your app uses a **dual-layer notification system** to ensure notifications work reliably whether the app is **open, closed, or device is in Doze mode**.

### Two Notification Methods:
1. **Native Android AlarmManager** (Primary) - Works when app is closed
2. **Flutter Local Notifications** (Removed as backup to prevent duplicates)

---

## 📊 Notification Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER ADDS/UPDATES BILL                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              CHECK: Are Notifications Enabled?               │
│              (NotificationSettingsProvider)                  │
└────────────┬────────────────────────────┬───────────────────┘
             │ NO                         │ YES
             ▼                            ▼
    ┌────────────────┐         ┌──────────────────────────┐
    │ Skip Scheduling│         │ Calculate Notification   │
    │ Return Early   │         │ Date & Time              │
    └────────────────┘         └──────────┬───────────────┘
                                          │
                                          ▼
                         ┌────────────────────────────────┐
                         │ Is Bill Paid or Deleted?       │
                         └────────┬───────────────┬───────┘
                                  │ YES           │ NO
                                  ▼               ▼
                         ┌────────────┐  ┌────────────────────┐
                         │ Cancel Any │  │ Is Time in Future? │
                         │ Existing   │  └────┬───────────┬───┘
                         │ Notification│      │ NO        │ YES
                         └────────────┘      ▼           ▼
                                    ┌────────────┐  ┌──────────────┐
                                    │ Skip       │  │ Schedule via │
                                    │ (Too Late) │  │ AlarmManager │
                                    └────────────┘  └──────┬───────┘
                                                           │
                                                           ▼
                                              ┌─────────────────────────┐
                                              │ Save to Tracking DB     │
                                              │ (Hive: scheduledNotifs) │
                                              └─────────────────────────┘
```

---

## 🔔 Notification Scheduling Logic

### 1. **When Notifications Are Scheduled**

Notifications are scheduled in these scenarios:

#### A. **Adding a New Bill**
```dart
// In BillProvider.addBill()
await _scheduleNotificationForBill(bill, forceReschedule: true);
```
- ✅ Always schedules (force reschedule = true)
- ✅ Works for both recurring and non-recurring bills

#### B. **Updating an Existing Bill**
```dart
// In BillProvider.updateBill()
if (!updatedBill.isPaid) {
  await _scheduleNotificationForBill(updatedBill, forceReschedule: true);
}
```
- ✅ Reschedules if bill is unpaid
- ❌ Cancels if bill is paid

#### C. **Marking Bill as Paid**
```dart
// In BillProvider.markBillAsPaid()
await NotificationService().cancelBillNotification(billId);
```
- ❌ Cancels notification immediately

#### D. **Undoing Payment**
```dart
// In BillProvider.undoBillPayment()
await _scheduleNotificationForBill(updatedBill, forceReschedule: true);
```
- ✅ Reschedules notification

#### E. **Toggling Notifications On/Off**
```dart
// In SettingsScreen
await billProvider.rescheduleAllNotifications();
```
- ✅ If enabled: Schedules for all unpaid bills
- ❌ If disabled: Cancels ALL notifications

---

## 🔄 Recurring vs Non-Recurring Bills

### **Non-Recurring Bills**
```
Bill Created → Notification Scheduled → Notification Fires → Done
```

**Example:**
- Bill: "Internet Bill" (Due: Jan 15, 2025)
- Reminder: 1 Day Before at 9:00 AM
- Notification fires: Jan 14, 2025 at 9:00 AM
- After firing: Notification is done (one-time)

---

### **Recurring Bills**
```
Parent Bill → Instance 1 → Notification 1 → Fires
           → Instance 2 → Notification 2 → Fires
           → Instance 3 → Notification 3 → Fires
           → ... (continues based on repeat pattern)
```

**Example:**
- Bill: "Rent" (Monthly, Starting Jan 1, 2025)
- Repeat Count: 12 (1 year)

**What Happens:**

1. **Initial Creation:**
   - Instance 1 created: Due Jan 1, 2025
   - Notification scheduled for Dec 31, 2024 at 9:00 AM

2. **After Instance 1 is Paid:**
   - RecurringBillService creates Instance 2: Due Feb 1, 2025
   - Notification scheduled for Jan 31, 2025 at 9:00 AM

3. **Sequence Tracking:**
   - Instance 1: `recurringSequence = 1`
   - Instance 2: `recurringSequence = 2`
   - Instance 3: `recurringSequence = 3`
   - Notification body includes: "Rent - $1000 (2 of 12)"

4. **Stopping Condition:**
   - When `recurringSequence` reaches `repeatCount` (12), no more instances are created
   - If `repeatCount = null`, continues indefinitely

---

## 🏗️ Technical Implementation

### **Step 1: Calculate Notification Time**

```dart
// In BillProvider._scheduleNotificationForBill()

// Get settings (per-bill or global)
int daysOffset = bill.reminderTiming != null 
    ? _getReminderDaysOffsetFromString(bill.reminderTiming!)
    : _notificationSettings!.getReminderDaysOffset();

int notificationHour = bill.notificationTime != null
    ? int.parse(bill.notificationTime!.split(':')[0])
    : _notificationSettings!.notificationTime.hour;

int notificationMinute = bill.notificationTime != null
    ? int.parse(bill.notificationTime!.split(':')[1])
    : _notificationSettings!.notificationTime.minute;

// Calculate notification date
final notificationDate = bill.dueAt.subtract(Duration(days: daysOffset));
final scheduledTime = DateTime(
  notificationDate.year,
  notificationDate.month,
  notificationDate.day,
  notificationHour,
  notificationMinute,
);
```

**Example Calculation:**
- Due Date: Jan 15, 2025
- Reminder: 1 Day Before
- Time: 9:00 AM
- **Notification fires:** Jan 14, 2025 at 9:00 AM

---

### **Step 2: Schedule via Native AlarmManager**

```dart
// In NotificationService.scheduleBillNotification()

final success = await NativeAlarmService.scheduleAlarm(
  dateTime: alarmTime,
  title: title,  // "Bill Due Tomorrow"
  body: body,    // "Rent - $1000 due to Landlord"
  notificationId: bill.id.hashCode,
  userId: userId,
  billId: bill.id,
  isRecurring: bill.repeat != 'none',
  recurringType: bill.repeat,
  currentSequence: bill.recurringSequence ?? 1,
  repeatCount: bill.repeatCount ?? -1,
);
```

**What NativeAlarmService Does:**
1. Calls Android AlarmManager via platform channel
2. Sets exact alarm (requires SCHEDULE_EXACT_ALARM permission)
3. Alarm survives app closure and device reboot
4. When alarm fires, it shows notification via Flutter Local Notifications

---

### **Step 3: Track Scheduled Notification**

```dart
// In NotificationHistoryService.trackScheduledNotification()

await trackingBox.put('scheduled_$billId', {
  'billId': billId,
  'billTitle': billTitle,
  'title': title,
  'body': body,
  'scheduledFor': scheduledFor.millisecondsSinceEpoch,
  'userId': userId,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
});
```

**Purpose:**
- Track which notifications are scheduled
- Prevent duplicate scheduling
- Allow cancellation of all notifications
- Associate notifications with specific users

---

## 📱 App Open vs Closed Behavior

### **When App is OPEN:**

```
AlarmManager Fires → Native Callback → Shows Notification
                                     ↓
                          User Taps Notification
                                     ↓
                          onNotificationTapped callback
                                     ↓
                          Navigate to BillManagerScreen
                                     ↓
                          Highlight the specific bill
```

**Code:**
```dart
// In main.dart
NotificationService.onNotificationTapped = (String? billId) async {
  if (billId != null && billId.isNotEmpty) {
    MyApp.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => BillManagerScreen(
          initialStatus: 'overdue',
          highlightBillId: billId,
        ),
      ),
      (route) => false,
    );
  }
};
```

---

### **When App is CLOSED:**

```
AlarmManager Fires → Native Callback → Shows Notification
                                     ↓
                          Notification Sits in Tray
                                     ↓
                          User Taps Notification
                                     ↓
                          App Launches
                                     ↓
                          onNotificationTapped callback
                                     ↓
                          Navigate to BillManagerScreen
```

**Key Difference:**
- App must launch first
- Then navigation happens
- Same end result: User sees the bill

---

## 🔐 Permissions Required

### **Android 13+ (API 33+)**
```xml
<!-- In AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```

### **Permission Flow:**
1. **POST_NOTIFICATIONS**: Asked on first app launch
2. **SCHEDULE_EXACT_ALARM**: Asked when scheduling first notification
3. If denied: Notifications won't work

---

## 🗄️ Database Structure

### **Hive Boxes Used:**

#### 1. **Bills Box** (`bills`)
```dart
{
  'id': 'uuid-123',
  'title': 'Rent',
  'amount': 1000.0,
  'dueAt': DateTime(2025, 1, 15),
  'repeat': 'monthly',
  'repeatCount': 12,
  'recurringSequence': 1,
  'parentBillId': null,  // null for parent, uuid for instances
  'reminderTiming': '1 Day Before',  // or null for global
  'notificationTime': '09:00',       // or null for global
  'isPaid': false,
  'isDeleted': false,
}
```

#### 2. **Scheduled Notifications Box** (`scheduledNotifications`)
```dart
{
  'scheduled_uuid-123': {
    'billId': 'uuid-123',
    'billTitle': 'Rent',
    'title': 'Bill Due Tomorrow',
    'body': 'Rent - $1000 due to Landlord (1 of 12)',
    'scheduledFor': 1705219200000,  // milliseconds
    'userId': 'user-abc',
    'createdAt': 1705132800000,
  }
}
```

#### 3. **Notification History Box** (`notificationHistory`)
```dart
{
  'history-uuid-456': {
    'id': 'history-uuid-456',
    'title': 'Bill Due Tomorrow',
    'body': 'Rent - $1000 due to Landlord',
    'billId': 'uuid-123',
    'billTitle': 'Rent',
    'userId': 'user-abc',
    'timestamp': 1705219200000,
    'isRead': false,
  }
}
```

---

## 🔄 Recurring Bill Lifecycle

### **Complete Flow for Monthly Recurring Bill:**

```
Day 0: User Creates Bill
├─ Bill: "Rent" (Monthly, 12 occurrences)
├─ Due: Jan 1, 2025
├─ Instance 1 created (sequence: 1)
└─ Notification scheduled: Dec 31, 2024 at 9:00 AM

Day 1: Notification Fires
├─ User sees: "Bill Due Tomorrow - Rent $1000 (1 of 12)"
└─ User taps → Opens app → Sees bill highlighted

Day 2: User Marks Bill as Paid
├─ Instance 1 marked as paid
├─ Notification cancelled
├─ RecurringBillService runs
├─ Instance 2 created (sequence: 2)
├─ Due: Feb 1, 2025
└─ Notification scheduled: Jan 31, 2025 at 9:00 AM

Day 31: Notification Fires Again
├─ User sees: "Bill Due Tomorrow - Rent $1000 (2 of 12)"
└─ Cycle repeats...

After 12 Months:
├─ Instance 12 paid
├─ recurringSequence (12) == repeatCount (12)
├─ No more instances created
└─ Recurring series complete
```

---

## 🛠️ Key Methods

### **1. Schedule Notification**
```dart
// BillProvider._scheduleNotificationForBill()
Future<void> _scheduleNotificationForBill(
  BillHive bill, {
  bool forceReschedule = false,
}) async {
  // Check if notifications enabled
  if (!_notificationSettings!.notificationsEnabled) return;
  
  // Check if bill is paid/deleted
  if (bill.isPaid || bill.isDeleted) return;
  
  // Calculate time
  // Schedule via AlarmManager
  // Track in database
}
```

### **2. Cancel Notification**
```dart
// NotificationService.cancelBillNotification()
Future<void> cancelBillNotification(String billId) async {
  // Cancel from flutter_local_notifications
  await _notifications.cancel(billId.hashCode);
  
  // Cancel from Native AlarmManager
  await NativeAlarmService.cancelAlarm(billId.hashCode);
  
  // Remove from tracking
  await NotificationHistoryService.removeScheduledTracking(billId);
}
```

### **3. Cancel All Notifications**
```dart
// NotificationService.cancelAllNotifications()
Future<void> cancelAllNotifications() async {
  // Cancel all flutter notifications
  await _notifications.cancelAll();
  
  // Cancel all native alarms (using tracking box)
  final trackingBox = await Hive.openBox('scheduledNotifications');
  for (var key in trackingBox.keys) {
    final data = trackingBox.get(key);
    final billId = data['billId'];
    await NativeAlarmService.cancelAlarm(billId.hashCode);
  }
  
  // Clear tracking
  await trackingBox.clear();
}
```

### **4. Reschedule All Notifications**
```dart
// BillProvider.rescheduleAllNotifications()
Future<void> rescheduleAllNotifications() async {
  if (!_notificationSettings!.notificationsEnabled) {
    // Cancel all if disabled
    await NotificationService().cancelAllNotifications();
    return;
  }
  
  // Reschedule for all unpaid bills
  for (final bill in _bills) {
    if (!bill.isPaid && !bill.isDeleted) {
      await _scheduleNotificationForBill(bill);
    }
  }
}
```

---

## 🎯 Notification Titles

Based on reminder timing:

| Reminder Timing | Notification Title |
|----------------|-------------------|
| Same Day | "Bill Due Today" |
| 1 Day Before | "Bill Due Tomorrow" |
| 2 Days Before | "Bill Due in 2 Days" |
| 1 Week Before | "Bill Due in 1 Week" |

---

## 📝 Notification Body Format

### **Non-Recurring:**
```
"Internet Bill - $50.00 due to Comcast"
```

### **Recurring (with count):**
```
"Rent - $1000.00 due to Landlord (2 of 12)"
```

### **Recurring (unlimited):**
```
"Rent - $1000.00 due to Landlord (#2)"
```

---

## 🐛 Common Issues & Solutions

### **Issue 1: Notifications Not Firing**
**Causes:**
- Notifications disabled in settings
- SCHEDULE_EXACT_ALARM permission not granted
- Notification time is in the past
- Battery optimization killing alarms

**Solution:**
```dart
// Check permissions
final canSchedule = await NotificationService().canScheduleExactAlarms();
if (!canSchedule) {
  // Show dialog to enable in settings
}
```

### **Issue 2: Duplicate Notifications**
**Cause:** Both AlarmManager and flutter_local_notifications firing

**Solution:** ✅ Already fixed - only using AlarmManager now

### **Issue 3: Notifications After Toggle Off**
**Cause:** Not calling `rescheduleAllNotifications()` after toggle

**Solution:** ✅ Already fixed - now calls it on toggle change

---

## 🔍 Debugging

### **Check Pending Notifications:**
```dart
final pending = await NotificationService().getPendingNotifications();
print('Pending: ${pending.length}');
for (var notif in pending) {
  print('ID: ${notif.id}, Title: ${notif.title}');
}
```

### **Check Scheduled Tracking:**
```dart
final trackingBox = await Hive.openBox('scheduledNotifications');
print('Tracked: ${trackingBox.length}');
for (var key in trackingBox.keys) {
  final data = trackingBox.get(key);
  print('Bill: ${data['billTitle']}, Time: ${DateTime.fromMillisecondsSinceEpoch(data['scheduledFor'])}');
}
```

---

## 📊 Summary

### **Notification Flow:**
1. User adds/updates bill
2. Check if notifications enabled
3. Calculate notification time
4. Schedule via AlarmManager
5. Track in database
6. Alarm fires at scheduled time
7. Notification shows (app open or closed)
8. User taps → Navigate to bill

### **Recurring Bills:**
- Each instance gets its own notification
- Sequence number tracked
- Next instance created after payment
- Stops when reaching repeat count

### **App States:**
- **Open:** Notification fires → Navigate immediately
- **Closed:** Notification fires → App launches → Navigate
- **Doze Mode:** AlarmManager ensures delivery

### **Key Features:**
- ✅ Works when app is closed
- ✅ Survives device reboot
- ✅ Per-bill or global settings
- ✅ Recurring bill support
- ✅ Notification history
- ✅ User-specific notifications
- ✅ Toggle on/off functionality

---

**Last Updated:** December 10, 2025
