# 🔔 Professional Notification System Implementation Plan

## Current State Analysis

### What Exists:
- ✅ AlarmManager integration via `NativeAlarmService`
- ✅ Basic notification scheduling in `NotificationService`
- ✅ Notification history tracking in `NotificationHistoryService`
- ✅ Bill model with recurring support (`BillHive`)
- ✅ Toggle ON/OFF functionality

### What's Missing (Per Requirements):
- ❌ **App OPEN vs CLOSED detection** - No in-app banner when app is open
- ❌ **notificationSent flag** - Not tracking if notification was sent
- ❌ **currentOccurrence tracking** - Not incrementing occurrence count
- ❌ **nextDueDate calculation** - Not calculating next occurrence properly
- ❌ **Sync on app launch** - Not checking missed notifications
- ❌ **History saved when toggle OFF** - Not saving to history when disabled
- ❌ **Occurrence number in history** - Not tracking occurrence number
- ❌ **1 minute recurring** - Not supported

---

## Implementation Strategy

### Phase 1: Update Data Models ✅
**Files:** `lib/models/bill_hive.dart`, `lib/models/notification_history.dart`

**Changes:**
1. Add to `BillHive`:
   - `bool notificationSent` - Track if notification was sent
   - `int currentOccurrence` - Track current occurrence number
   - `DateTime? nextDueDate` - Track next due date for recurring

2. Add to `NotificationHistory`:
   - `int? occurrenceNumber` - Track which occurrence this was
   - `bool isRecurring` - Track if from recurring bill
   - `String notificationType` - Type: 'scheduled', 'missed', 'in_app'

### Phase 2: App State Detection Service ✅
**New File:** `lib/services/app_state_service.dart`

**Purpose:** Detect if app is in foreground or background

**Methods:**
- `bool isAppInForeground()` - Check current app state
- `Stream<AppLifecycleState> get stateStream` - Listen to state changes
- `void init()` - Initialize lifecycle observer

### Phase 3: In-App Notification Service ✅
**New File:** `lib/services/in_app_notification_service.dart`

**Purpose:** Show in-app banners when app is open

**Methods:**
- `void showInAppNotification(BuildContext, String title, String body, String billId)`
- `void showSnackBar(BuildContext, String message)`

### Phase 4: Update NotificationService ✅
**File:** `lib/services/notification_service.dart`

**Changes:**
1. Add app state check before showing notification
2. If app OPEN → Call in-app service
3. If app CLOSED → Show native notification
4. Always save to history regardless of toggle state
5. Update occurrence tracking

### Phase 5: Recurring Logic Enhancement ✅
**File:** `lib/services/recurring_bill_service.dart`

**Changes:**
1. Support "1 minute" recurring type
2. Calculate `nextDueDate` properly
3. Increment `currentOccurrence` after notification
4. Stop when `currentOccurrence >= totalOccurrences`
5. Schedule next occurrence automatically

### Phase 6: Sync on App Launch ✅
**File:** `lib/providers/bill_provider.dart` → `initialize()` method

**Changes:**
1. Check all bills on app start
2. For each bill where `nextDueDate < now`:
   - Fire in-app notification
   - Save to history
   - Update occurrence
   - Reschedule next

### Phase 7: Toggle OFF Behavior ✅
**File:** `lib/providers/bill_provider.dart` → `rescheduleAllNotifications()`

**Changes:**
1. When toggle OFF:
   - Cancel all scheduled notifications
   - BUT still check for due bills
   - Save missed notifications to history
   - Don't show notifications

### Phase 8: History Enhancement ✅
**File:** `lib/services/notification_history_service.dart`

**Changes:**
1. Add occurrence tracking
2. Add notification type tracking
3. Save even when toggle is OFF
4. Save even when app is open

### Phase 9: Native Alarm Callback Update ✅
**File:** `android/app/src/main/kotlin/.../AlarmReceiver.kt`

**Changes:**
1. Check app state before showing notification
2. If app open → Send to Flutter via method channel
3. If app closed → Show native notification
4. Update occurrence in database

### Phase 10: UI Updates ✅
**Files:** Various screens

**Changes:**
1. Show in-app banners
2. Update notification history UI to show occurrence numbers
3. Add notification type badges

---

## Detailed Implementation

### 1. Update BillHive Model

```dart
@HiveField(24)
bool notificationSent; // Has notification been sent for current occurrence

@HiveField(25)
int currentOccurrence; // Current occurrence number (1, 2, 3...)

@HiveField(26)
DateTime? nextDueDate; // Next due date for recurring bills
```

### 2. Update NotificationHistory Model

```dart
@HiveField(8)
int? occurrenceNumber; // Which occurrence (1 of 12, 2 of 12, etc.)

@HiveField(9)
bool isRecurring; // Is this from a recurring bill

@HiveField(10)
String notificationType; // 'scheduled', 'missed', 'in_app', 'background'
```

### 3. App State Service

```dart
class AppStateService {
  static AppLifecycleState _currentState = AppLifecycleState.resumed;
  
  static bool get isAppInForeground => 
    _currentState == AppLifecycleState.resumed;
  
  static void init() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }
}
```

### 4. Notification Trigger Logic

```dart
Future<void> triggerNotification(BillHive bill) async {
  // Check: Should we send?
  if (bill.isPaid || bill.isDeleted) return;
  if (bill.repeat != 'none' && 
      bill.currentOccurrence >= (bill.repeatCount ?? 999)) return;
  
  final now = DateTime.now();
  final dueDate = bill.nextDueDate ?? bill.dueAt;
  
  // Check if it's time
  if (now.isBefore(dueDate)) return;
  
  // Check if already sent
  if (bill.notificationSent) return;
  
  // Determine notification type
  final isAppOpen = AppStateService.isAppInForeground;
  final notificationsEnabled = _notificationSettings.notificationsEnabled;
  
  String notificationType;
  if (isAppOpen) {
    notificationType = 'in_app';
    // Show in-app banner
    InAppNotificationService.show(title, body, billId);
  } else {
    notificationType = 'background';
    if (notificationsEnabled) {
      // Show native notification
      await NativeAlarmService.showNotification(title, body);
    }
  }
  
  // ALWAYS save to history (even if toggle OFF)
  await NotificationHistoryService.addNotification(
    title: title,
    body: body,
    billId: bill.id,
    occurrenceNumber: bill.currentOccurrence,
    isRecurring: bill.repeat != 'none',
    notificationType: notificationType,
  );
  
  // Update bill
  if (bill.repeat != 'none') {
    // Recurring: increment and schedule next
    bill.currentOccurrence++;
    bill.nextDueDate = calculateNextDueDate(bill);
    bill.notificationSent = false; // Reset for next occurrence
    
    // Schedule next occurrence
    await scheduleNotification(bill);
  } else {
    // Non-recurring: mark as sent
    bill.notificationSent = true;
  }
  
  await HiveService.saveBill(bill);
}
```

### 5. Calculate Next Due Date

```dart
DateTime calculateNextDueDate(BillHive bill) {
  final current = bill.nextDueDate ?? bill.dueAt;
  
  switch (bill.repeat) {
    case '1 minute':
      return current.add(Duration(minutes: 1));
    case 'daily':
      return current.add(Duration(days: 1));
    case 'weekly':
      return current.add(Duration(days: 7));
    case 'monthly':
      return DateTime(
        current.month == 12 ? current.year + 1 : current.year,
        current.month == 12 ? 1 : current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );
    case 'yearly':
      return DateTime(
        current.year + 1,
        current.month,
        current.day,
        current.hour,
        current.minute,
      );
    default:
      return current;
  }
}
```

### 6. Sync on App Launch

```dart
Future<void> syncMissedNotifications() async {
  final bills = HiveService.getAllBills();
  final now = DateTime.now();
  
  for (final bill in bills) {
    if (bill.isPaid || bill.isDeleted) continue;
    
    final dueDate = bill.nextDueDate ?? bill.dueAt;
    
    // If notification time has passed and not sent
    if (dueDate.isBefore(now) && !bill.notificationSent) {
      // Fire in-app notification
      await triggerNotification(bill);
    }
  }
}
```

---

## Testing Checklist

### Non-Recurring Bills
- [ ] Notification fires once at correct time
- [ ] `notificationSent` set to true after firing
- [ ] Saved to history
- [ ] Works when app open (in-app banner)
- [ ] Works when app closed (native notification)

### Recurring Bills (1 minute)
- [ ] First occurrence fires
- [ ] `currentOccurrence` increments (1 → 2 → 3)
- [ ] `nextDueDate` calculated correctly
- [ ] Next occurrence scheduled automatically
- [ ] Stops after reaching `repeatCount`
- [ ] Each occurrence saved to history with number

### Toggle OFF
- [ ] All notifications cancelled
- [ ] Due bills still saved to history
- [ ] No native notifications shown
- [ ] History shows "missed" type

### App Launch Sync
- [ ] Missed notifications detected
- [ ] In-app banners shown for missed
- [ ] Occurrences updated
- [ ] Next occurrences scheduled

### History
- [ ] Shows occurrence number (1 of 12)
- [ ] Shows notification type badge
- [ ] Saved even when toggle OFF
- [ ] Saved even when app open

---

## File Changes Summary

### New Files (3):
1. `lib/services/app_state_service.dart`
2. `lib/services/in_app_notification_service.dart`
3. `lib/services/notification_trigger_service.dart`

### Modified Files (8):
1. `lib/models/bill_hive.dart` - Add 3 fields
2. `lib/models/notification_history.dart` - Add 3 fields
3. `lib/services/notification_service.dart` - Add app state check
4. `lib/services/recurring_bill_service.dart` - Add 1 minute support
5. `lib/providers/bill_provider.dart` - Add sync on launch
6. `lib/services/notification_history_service.dart` - Add occurrence tracking
7. `lib/services/native_alarm_service.dart` - Add app state check
8. `android/app/src/main/kotlin/.../AlarmReceiver.kt` - Add app state check

### Regenerate (1):
1. `lib/models/bill_hive.g.dart` - Run `flutter pub run build_runner build`

---

## Implementation Order

1. ✅ Update models (BillHive, NotificationHistory)
2. ✅ Regenerate Hive adapters
3. ✅ Create AppStateService
4. ✅ Create InAppNotificationService
5. ✅ Create NotificationTriggerService (central logic)
6. ✅ Update NotificationService (use trigger service)
7. ✅ Update RecurringBillService (1 minute support)
8. ✅ Update BillProvider (sync on launch)
9. ✅ Update NotificationHistoryService (occurrence tracking)
10. ✅ Update NativeAlarmService (app state check)
11. ✅ Update Android AlarmReceiver (app state check)
12. ✅ Test thoroughly

---

**Estimated Time:** 4-6 hours for complete implementation
**Complexity:** High (touches 11+ files, requires Android native code)
**Risk:** Medium (requires careful testing of notification timing)

Ready to proceed with implementation?
