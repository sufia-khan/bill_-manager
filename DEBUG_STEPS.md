# Debug Steps - Scheduled Notification Not Appearing

## Step 1: Check the Console Logs

Connect your phone via USB and run:
```bash
flutter logs
```

Then tap "Test Scheduled Notification" and look for these messages:

**What you SHOULD see:**
```
🧪 Starting test notification scheduling...
📱 Notifications enabled: true
⏰ Can schedule exact alarms: true
⏰ Current time: 2025-10-25 14:30:00.000
⏰ Scheduled time: 2025-10-25 14:30:10.000
🔔 Scheduling notification:
   ID: 999999
   Title: Scheduled Test Notification
✅ Test notification scheduled successfully!
📋 Total pending notifications: 1
   - ID: 999999, Title: Scheduled Test Notification
```

**What might be wrong:**
```
📱 Notifications enabled: false  ← Permission issue
⏰ Can schedule exact alarms: false  ← Missing exact alarm permission
❌ Error scheduling test notification: ...  ← Something failed
```

## Step 2: Check Notification Status in App

1. Open the app
2. Go to Settings
3. Tap **"Check Notification Status"**

You should see:
- ✅ Notifications Enabled: **Yes**
- ✅ Exact Alarms Enabled: **Yes**
- Pending Notifications: **1** (after scheduling)

If you see any "No", that's the problem!

## Step 3: Check Pending Notifications

1. Go to Settings
2. Tap **"View Scheduled Notifications"**

You should see:
- **Scheduled Test Notification** listed

If the list is empty, the notification wasn't scheduled.

## Step 4: Grant Exact Alarm Permission (CRITICAL for Android 12+)

This is the #1 reason scheduled notifications don't work!

**On your phone:**
1. Go to **Settings**
2. **Apps** → **BillManager**
3. Look for **"Alarms & reminders"** or **"Set alarms and reminders"**
4. **Enable it**

Without this permission, scheduled notifications will NOT work on Android 12+!

## Step 5: Test Again

After granting permissions:
1. Tap "Test Scheduled Notification"
2. Check console logs (should show "✅ Test notification scheduled successfully!")
3. Check "View Scheduled Notifications" (should show 1 notification)
4. **Close the app completely** (swipe away from recent apps)
5. Wait 10 seconds
6. Notification should appear!

## Common Issues

### Issue: "Can schedule exact alarms: false"

**This is the most common issue!**

**Fix:**
```
Settings > Apps > BillManager > Alarms & reminders > Enable
```

On some phones it might be called:
- "Set alarms and reminders"
- "Schedule exact alarms"
- "Alarms"

### Issue: Pending notifications list is empty

**Causes:**
- Permission denied
- Error during scheduling
- App doesn't have exact alarm permission

**Fix:**
1. Check console logs for errors
2. Grant exact alarm permission
3. Try scheduling again

### Issue: Notification appears but much later

**Cause:** Battery optimization

**Fix:**
```
Settings > Apps > BillManager > Battery > Unrestricted
```

### Issue: Immediate notification works, scheduled doesn't

**This confirms it's the exact alarm permission!**

Immediate notifications don't need exact alarm permission, but scheduled ones do.

## What to Share

If it's still not working, please share:

1. **Console logs** (the output from `flutter logs`)
2. **"Check Notification Status" screenshot** (from the app)
3. **Android version** (Settings > About phone)
4. **Phone model** (e.g., Samsung Galaxy S21, Pixel 6, etc.)

This will help me identify the exact issue!
