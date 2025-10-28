# How to Add Notification Test Button

## Quick Setup

Add the test button to your Settings screen to verify notifications work.

### Step 1: Import the Widget

Add this import at the top of `lib/screens/settings_screen.dart`:

```dart
import '../widgets/notification_test_button.dart';
```

### Step 2: Add the Widget

Find a good place in your settings screen (maybe after the notification settings section) and add:

```dart
const SizedBox(height: 20),
const NotificationTestButton(),
```

### Example Integration:

```dart
// In your settings screen build method
SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    children: [
      // ... your existing settings widgets ...
      
      // Notification Settings Section
      _buildNotificationSettings(),
      
      const SizedBox(height: 20),
      
      // ADD THIS: Test Notification Button
      const NotificationTestButton(),
      
      const SizedBox(height: 20),
      
      // ... rest of your settings ...
    ],
  ),
)
```

## What It Does

The test button widget provides three testing options:

### 1. Test Immediate Notification
- Sends a notification right away
- Verifies basic notification functionality
- Should appear instantly

### 2. Test Scheduled (10 sec)
- Schedules a notification for 10 seconds from now
- **Close the app** after clicking this
- Verifies notifications work when app is closed
- This is the most important test!

### 3. Show Pending Notifications
- Lists all scheduled notifications
- Shows notification IDs, titles, and bodies
- Useful for debugging

## Testing Workflow

### Test 1: Basic Functionality
1. Click "Test Immediate Notification"
2. You should see a notification immediately
3. ✅ If you see it, basic notifications work

### Test 2: Scheduled Notifications (App Closed)
1. Click "Test Scheduled (10 sec)"
2. **Immediately close the app** (swipe it away from recent apps)
3. Wait 10 seconds
4. ✅ If notification appears, scheduled notifications work when app is closed!

### Test 3: Real Bill Notification
1. Add a new bill
2. Set due date to tomorrow
3. Set reminder to "Same Day"
4. Set time to 2 minutes from now
5. Close the app
6. Wait 2 minutes
7. ✅ If notification appears, your bill notifications are working!

## Troubleshooting

### If Test 1 Fails (Immediate Notification)
**Problem:** Basic notifications not working
**Solution:**
- Go to Settings > Apps > BillManager > Notifications
- Ensure notifications are enabled
- Try granting permission again

### If Test 2 Fails (Scheduled with App Closed)
**Problem:** Scheduled notifications not working when app is closed
**Solution:**
1. Check exact alarm permission:
   - Settings > Apps > BillManager > Alarms & reminders
   - Enable "Allow setting alarms and reminders"

2. Disable battery optimization:
   - Settings > Apps > BillManager > Battery
   - Select "Unrestricted"

3. Check Doze mode settings:
   - Settings > Battery > Battery optimization
   - Find BillManager and set to "Don't optimize"

### If Test 3 Fails (Real Bill)
**Problem:** Bill notifications not triggering
**Solution:**
- Check the logs in debug console
- Look for "✅ Notification scheduled" message
- Verify the calculated time is correct
- Ensure the bill is not marked as paid
- Try clicking "Show Pending Notifications" to see if it's scheduled

## Expected Behavior

### When Everything Works:
1. ✅ Immediate notifications appear instantly
2. ✅ Scheduled notifications appear at exact time
3. ✅ Notifications work when app is closed
4. ✅ Notifications work when phone is locked
5. ✅ Bill notifications trigger at the right time
6. ✅ Notifications survive device reboot (after opening app once)

## Debug Console Output

When you test, look for these logs:

```
🔔 Showing immediate notification...
   Title: Test Notification
   Body: If you see this, notifications are working! ✅
📱 Notifications enabled: true
✅ Immediate notification shown successfully!
```

For scheduled notifications:
```
🧪 Starting test notification scheduling...
⏰ Current time: 2025-10-26 14:30:00
⏰ Scheduled time: 2025-10-26 14:30:10
✅ Test notification scheduled successfully via Native AlarmManager!
```

## Quick Reference

| Test | Purpose | Expected Result |
|------|---------|----------------|
| Immediate | Basic functionality | Notification appears instantly |
| Scheduled (10s) | App closed test | Notification appears after 10s with app closed |
| Pending List | Debug info | Shows all scheduled notifications |

## Next Steps

After verifying notifications work:
1. Remove or comment out the test button (optional)
2. Test with real bills
3. Inform users about permission requirements
4. Add user guide about battery optimization

The test button is safe to keep in production - it's useful for users to verify their notifications are working!
