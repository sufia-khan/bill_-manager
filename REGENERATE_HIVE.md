# Important: Regenerate Hive Adapters

After adding the new `reminderTimings` field to `BillHive`, you need to regenerate the Hive type adapters.

## Run this command:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will regenerate the `bill_hive.g.dart` file with the new field included.

## What was changed:

1. Added `@HiveField(21) List<String>? reminderTimings` to `BillHive` model
2. Updated `copyWith`, `toFirestore`, and `fromFirestore` methods
3. Updated `BillProvider` to handle multiple reminders
4. Updated `AddBillScreen` to allow selecting multiple reminder options

## Features:

- Users can now select multiple reminder timings (Same Day, 1 Day Before, 2 Days Before, 1 Week Before)
- Multiple notifications will be scheduled for each selected reminder
- Backward compatible with existing single reminder setup
- UI shows selected reminders as chips that can be removed individually
