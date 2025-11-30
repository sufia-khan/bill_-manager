# Archive Management System

## Overview
A comprehensive archive management system with auto-delete, pinning, and user preferences.

## Features Added

### 1. **Auto-Delete After 90 Days**
- Archived bills are automatically deleted 90 days after archiving
- User can enable/disable this feature in Settings
- Default: **Enabled**

### 2. **Pin Bills to Prevent Deletion**
- Users can pin important archived bills
- Pinned bills are **never** auto-deleted
- Pin/Unpin button in archived bills screen

### 3. **User Preferences**
- Toggle in Settings: "Auto-delete archived bills after 90 days"
- Preference stored in Hive
- Persists across app restarts

### 4. **Visual Indicators**
- Bills at risk (< 7 days until deletion) show red badge with days remaining
- Pinned bills show gold pin icon
- Clear visual feedback

## New Fields Added

### BillHive Model
- `isPinned` (bool) - Exclude from auto-delete
- `archivedAt` (DateTime) - Already existed, now used for auto-delete calculation

## Files Modified

### Models
- `lib/models/bill_hive.dart` - Added `isPinned` field

### Services
- `lib/services/archive_management_service.dart` - **NEW** - Core logic
- `lib/services/user_preferences_service.dart` - Added auto-delete preference
- `lib/services/bill_archival_service.dart` - Updated to use new service

### Screens
- `lib/screens/settings_screen.dart` - Added auto-delete toggle
- `lib/screens/archived_bills_screen.dart` - Added pin/unpin button

### App Initialization
- `lib/main.dart` - Added auto-cleanup on startup

## How It Works

### Auto-Delete Logic
```dart
// Bill is eligible for deletion if:
1. isArchived == true
2. isPinned == false
3. archivedAt != null
4. archivedAt is older than 90 days
5. User has auto-delete enabled
```

### Pin/Unpin
- Tap "Pin" button on any archived bill
- Pinned bills show gold pin icon
- Pinned bills are excluded from auto-delete
- Can unpin anytime

### Settings Toggle
- Settings > "Auto-delete archived bills after 90 days"
- Toggle ON/OFF
- When OFF, no bills are auto-deleted (even unpinned ones)

## User Experience

### Archived Bills Screen
Each bill shows:
- **Pin button** (left side)
  - "Pin" for unpinned bills
  - "Pinned" for pinned bills (gold)
  - Red badge showing days until deletion (if < 7 days)
- **Restore button** (right side)

### Settings Screen
- Clear toggle with subtitle
- Instant feedback on change
- Shows current state

### Auto-Cleanup
- Runs on app startup
- Silent operation
- Only deletes eligible bills
- Respects user preferences

## Testing

### Test Auto-Delete
1. Archive a bill
2. Manually set `archivedAt` to 91 days ago (in database)
3. Restart app
4. Bill should be deleted (if auto-delete enabled and not pinned)

### Test Pin Feature
1. Go to Archived Bills
2. Tap "Pin" on any bill
3. Icon changes to gold "Pinned"
4. Bill won't be auto-deleted

### Test Settings Toggle
1. Go to Settings
2. Toggle "Auto-delete archived bills"
3. When OFF, no bills are deleted
4. When ON, eligible bills are deleted on next startup

## Important Notes

⚠️ **Pinned bills are NEVER deleted** - Even if auto-delete is enabled

⚠️ **Auto-delete respects user preference** - If disabled, nothing is deleted

⚠️ **Archived bills never trigger reminders** - They're excluded from notification scheduling

⚠️ **Deleted bills sync to Firebase** - Marked as `isDeleted: true` and synced

## Future Enhancements

- Manual "Clean up now" button in Settings
- Customizable auto-delete period (30, 60, 90, 180 days)
- Bulk pin/unpin operations
- Export archived bills before deletion
- Notification before auto-deletion

---

The archive management system is now fully functional and ready for use!
