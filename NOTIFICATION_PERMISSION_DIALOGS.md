# Notification Permission Dialogs

## Overview
Simple and clear notification permission handling with warnings at key moments to ensure users understand when they won't receive bill reminders.

## Implementation

### 1. App Startup Dialog (main.dart)
When the app starts and the user is logged in, if notifications are disabled, a dialog appears:
- **Title**: "Enable Notifications?"
- **Message**: "Stay on top of your bills with timely reminders."
- **Warning**: "You will not receive bill reminders if notifications are disabled."
- **Actions**: 
  - "Not Now" - Dismisses dialog, keeps notifications off
  - "Allow" - Enables notifications and requests system permissions

**Permission Denied Handling:**
- If user denies system permission, shows "Permission Denied" warning
- Explains that notifications won't work
- Provides instructions to enable in phone settings: Settings > Apps > BillManager > Notifications
- Automatically disables notifications in app

### 2. Settings Screen Toggle (settings_screen.dart)
When user tries to turn OFF notifications from the settings screen:
- **Title**: "Turn Off Notifications?"
- **Message**: "Are you sure you want to disable notifications?"
- **Warning**: "You will not receive bill reminders if notifications are disabled."
- **Actions**:
  - "Cancel" - Keeps notifications enabled
  - "Turn Off" - Disables notifications and cancels all scheduled reminders

**When Enabling:**
- Simply enables notifications in app
- Reschedules all bill reminders
- Shows success message

### 3. Notification Service Enhancement (notification_service.dart)
Added `areNotificationsEnabled()` method:
- Checks Android system-level notification status
- Returns true/false based on actual permission state
- Used to verify permissions at app startup

## Features
✅ Clear warning messages with orange warning icon
✅ Non-dismissible dialogs (must choose an option)
✅ Consistent styling with app theme (orange & white)
✅ Automatic notification rescheduling when enabled
✅ Automatic notification cancellation when disabled
✅ Success feedback after enabling notifications
✅ Permission denied warnings only at app startup (not in settings)
✅ Simple user experience without over-complicating

## User Experience Flow

**Scenario 1: User denies at app startup**
1. App asks to enable notifications
2. User clicks "Allow"
3. System permission dialog appears
4. User denies
5. App shows "Permission Denied" warning with instructions
6. Notifications remain disabled in app

**Scenario 2: User enables in settings**
1. User toggles notifications ON in settings
2. Notifications enabled immediately
3. All bill reminders rescheduled
4. Success message shown

**Scenario 3: User disables in settings**
1. User toggles notifications OFF
2. App shows confirmation dialog with warning
3. User confirms
4. Notifications disabled
5. All scheduled notifications cancelled

## Benefits
- Simple and straightforward user experience
- Clear warnings at critical moments
- No over-complication with repeated permission checks
- Users understand consequences before disabling
- Proper system-level permission handling at startup only
