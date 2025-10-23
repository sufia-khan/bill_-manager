# Bill Lifecycle Analysis - 1 Minute Recurring Bill

## Your Scenario
You added a recurring bill with:
- **Repeat**: 1 Minute (Testing)
- **Due Date**: Today
- **Action**: Marked as paid

## When Will the Next Bill Be Auto-Added?

### Answer: **On Next App Restart**

The next instance of your 1-minute recurring bill will be automatically created when you:
1. **Close the app completely** (force close or swipe away)
2. **Reopen the app**

### Why Not Immediately?

Looking at the code in `lib/providers/bill_provider.dart` (line 135-175), when you mark a bill as paid:

```dart
// Mark bill as paid
Future<void> markBillAsPaid(String billId) async {
  // ... marks bill as paid ...
  
  // DON'T run recurring maintenance immediately - let it run on next app startup
  // This prevents creating a new instance right after marking as paid
  // The user will see the bill disappear cleanly
}
```

**Design Decision**: The system intentionally does NOT create the next instance immediately when you mark a bill as paid. This provides a cleaner user experience - the bill disappears to history without immediately showing a new one.

## Automatic Maintenance Schedule

The recurring bill maintenance runs automatically:

### 1. **On App Startup** (Primary Trigger)
- Location: `lib/providers/bill_provider.dart` line 48-53
- Timing: 2 seconds after app initialization
- Code:
```dart
Future.delayed(const Duration(seconds: 2), () async {
  try {
    await runMaintenance();
  } catch (e) {
    print('Error running maintenance on initialization: $e');
  }
});
```

### 2. **What Maintenance Does**
The `runMaintenance()` method (line 471-505):
- Calls `RecurringBillService.processRecurringBills()`
- Checks all recurring bills
- Creates next instances for bills that are:
  - **Paid** (isPaid = true), OR
  - **Past due date** (dueAt < now)

### 3. **For Your 1-Minute Bill**
When you restart the app:
1. App initializes
2. After 2 seconds, maintenance runs
3. System finds your paid bill with repeat = "1 minute (testing)"
4. Calculates next due date: `currentDueDate + 1 minute`
5. Creates new bill instance with:
   - Same title, vendor, amount, category
   - New due date (1 minute after original)
   - isPaid = false (unpaid)
   - New unique ID
   - Sequence number incremented

## Testing the Feature

### Quick Test Steps:
1. ✅ Add bill with "1 Minute (Testing)" repeat
2. ✅ Mark it as paid
3. ✅ Bill moves to "Past Bills" (history)
4. ✅ Close app completely
5. ✅ Reopen app
6. ✅ Wait 2 seconds
7. ✅ New instance appears in "Upcoming Bills"

### Expected Timeline:
```
Time 0:00 - Add recurring bill (due today)
Time 0:05 - Mark as paid → moves to history
Time 0:10 - Close app
Time 0:15 - Reopen app
Time 0:17 - (2 seconds later) Maintenance runs
Time 0:17 - New bill instance created (due 1 minute after original)
```

## Code Flow

### When You Mark as Paid:
```
User taps "Mark as Paid"
  ↓
markBillAsPaid() called
  ↓
Bill updated: isPaid = true, paidAt = now
  ↓
Bill saved to Hive
  ↓
UI refreshes (bill disappears from upcoming)
  ↓
Bill now in "Past Bills" section
  ↓
NO maintenance triggered (intentional)
```

### When You Restart App:
```
App starts
  ↓
BillProvider initializes
  ↓
Wait 2 seconds
  ↓
runMaintenance() called
  ↓
processRecurringBills() runs
  ↓
Finds your paid bill (isPaid = true)
  ↓
Checks: repeat = "1 minute (testing)" ✓
  ↓
Calculates: nextDueDate = dueAt + 1 minute
  ↓
Checks: next instance already exists? No
  ↓
Creates new bill instance
  ↓
Saves to Hive
  ↓
UI refreshes
  ↓
New bill appears in "Upcoming Bills"
```

## Important Notes

### Repeat Count Limit
If you set a repeat count (e.g., "3 times"), the system will:
- Track sequence: 1st instance, 2nd instance, 3rd instance
- Stop creating new instances after reaching the limit
- Check in `RecurringBillService.createNextInstance()` line 155-165

### Duplicate Prevention
The system prevents duplicate bills:
- Checks if next instance already exists
- Uses 1-day tolerance window
- Located in `hasNextInstance()` method line 113-145

### Background Processing
- Maintenance runs in a separate isolate for performance
- Won't block the UI
- Handles errors gracefully

## Summary

**Your 1-minute recurring bill will auto-create the next instance when you restart the app** (after a 2-second delay). This is by design to provide a clean user experience when marking bills as paid.

For production use, you'd typically use:
- **Weekly** - next instance 7 days later
- **Monthly** - next instance 1 month later
- **Yearly** - next instance 1 year later

The "1 Minute (Testing)" option is perfect for testing the recurring functionality quickly!
