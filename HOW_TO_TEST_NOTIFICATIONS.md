# How to Test Your Bill Notifications

## Quick Start Guide

Your notification system is now fully configured! Follow these steps to test it.

## Step 1: Check Permissions

1. Open the app
2. Go to **Settings** (bottom navigation)
3. Scroll down to find **"Test Notifications"**
4. Tap on it
5. Tap **"Check Permissions"**

You should see:
- ✅ Notifications: Enabled
- ✅ Exact Alarms: Enabled

If you see ❌ on either:
- Go to your phone's Settings > Apps > BillManager
- Enable "Notifications"
- Enable "Alarms & reminders"

## Step 2: Test Immediate Notification

1. In the Test Notifications screen
2. Tap **"Test Immediate Notification"**
3. You should see a notification immediately

✅ **If you see the notification:** Great! Notifications are working.
❌ **If you don't see it:** Check permissions again.

## Step 3: Test Scheduled Notification (App Closed)

This is the important test - it verifies notifications work when the app is closed.

1. In the Test Notifications screen
2. Tap **"Test Scheduled Notification"**
3. You'll see: "Notification scheduled for 10 seconds from now"
4. **Close the app completely** (swipe it away from recent apps)
5. Wait 10 seconds
6. You should see a notification!

✅ **If you see the notification:** Perfect! Your notifications will work for bills.
❌ **If you don't see it:** See troubleshooting below.

## Step 4: Test with a Real Bill

Now test with an actual bill:

1. Go to home screen
2. Tap the **+ button** to add a bill
3. Fill in:
   - Title: "Test Bill"
   - Amount: 10
   - Due Date: Tomorrow
   - Reminder: "Same Day"
   - Time: **Set to 2 minutes from now**
4. Save the bill
5. Close the app completely
6. Wait 2 minutes
7. You should get a notification!

## Understanding Your Notification Settings

When you add a bill, you can customize:

### Reminder Day Options:
- **Same Day** - Get notified on the due date
- **1 Day Before** - Get notified the day before
- **2 Days Before** - Get notified 2 days before
- **1 Week Before** - Get notified a week before

### Notification Time:
- Set any time you want (e.g., 7:00 AM, 9:00 PM)
- The notification will appear at exactly that time

### Example:
- Bill due: October 27, 2025
- Reminder: "1 Day Before"
- Time: "7:00 AM"
- **You'll get notified: October 26, 2025 at 7:00 AM**

## Troubleshooting

### Problem: "Exact alarm permission not granted"

**Solution:**
1. Go to Settings > Apps > BillManager
2. Tap "Alarms & reminders"
3. Enable "Allow setting alarms and reminders"
4. This is required for Android 12+

### Problem: Notifications don't show when app is closed

**Solution:**
1. Disable battery optimization:
   - Settings > Apps > BillManager > Battery
   - Select "Unrestricted"
2. Make sure "Alarms & reminders" is enabled
3. Don't use third-party battery saver apps

### Problem: Notifications disappear after phone restart

**Solution:**
- Open the app once after restarting your phone
- All notifications will be automatically rescheduled
- This is normal behavior

### Problem: Wrong notification time

**Check:**
- Your phone's timezone settings
- The time you set in the app
- The app uses your device's local time

## Device-Specific Issues

Some phone manufacturers are aggressive with battery saving:

### Samsung:
- Settings > Apps > BillManager > Battery > Unrestricted
- Settings > Device care > Battery > App power management > Add BillManager to "Apps that won't be put to sleep"

### Xiaomi/MIUI:
- Settings > Apps > Manage apps > BillManager > Autostart > Enable
- Settings > Apps > Manage apps > BillManager > Battery saver > No restrictions

### Huawei:
- Settings > Apps > BillManager > Battery > App launch > Manage manually
- Enable all three options (Auto-launch, Secondary launch, Run in background)

### OnePlus/Oppo:
- Settings > Apps > BillManager > Battery > Battery optimization > Don't optimize

## Verification Checklist

Test these scenarios to ensure everything works:

- [ ] Immediate notification works
- [ ] Scheduled notification works (10 seconds test)
- [ ] Notification works when app is closed
- [ ] Notification works when phone is locked
- [ ] Real bill notification works (2-minute test)
- [ ] Custom reminder day works (Same Day, 1 Day Before, etc.)
- [ ] Custom time works (7:00 AM, 9:00 PM, etc.)
- [ ] Multiple bills have separate notifications
- [ ] After phone restart, open app and notifications reschedule

## How It Works Behind the Scenes

When you add a bill:

1. **App calculates notification time:**
   - Takes your due date
   - Subtracts the reminder days (0, 1, 2, or 7)
   - Sets the time you specified

2. **Schedules with Android:**
   - Uses Android's AlarmManager
   - Sets `exactAllowWhileIdle` mode
   - This works even in Doze mode

3. **Notification triggers:**
   - At the exact time you specified
   - Even if app is closed
   - Even if phone is locked
   - Even in battery saver mode

## Debug Information

If you need to see what's happening:

1. Go to Settings > Test Notifications
2. Tap "View Pending Notifications"
3. You'll see all scheduled notifications

Or check the app logs when adding a bill:
```
✅ Notification scheduled successfully:
   Bill: Water Bill
   Due Date: 2025-10-27
   Days Before: 1
   Scheduled Time: 2025-10-26 07:00:00
```

## Best Practices

To ensure notifications always work:

1. ✅ Grant all permissions when asked
2. ✅ Disable battery optimization for the app
3. ✅ Open the app once after phone restart
4. ✅ Don't force-stop the app from settings
5. ✅ Keep the app updated

## Summary

Your notification system uses:
- ✅ Android's native AlarmManager
- ✅ `exactAllowWhileIdle` for reliability
- ✅ Highest priority settings
- ✅ Proper permissions
- ✅ Auto-rescheduling on app startup

This is the most reliable method available for scheduled notifications on Android!

## Need Help?

If notifications still don't work after following all steps:
1. Check your phone manufacturer's battery optimization settings
2. Make sure you're not using aggressive battery saver apps
3. Try the test notifications in the app
4. Check the debug logs in Settings > Test Notifications

The implementation follows Android best practices and should work on all modern Android devices.
