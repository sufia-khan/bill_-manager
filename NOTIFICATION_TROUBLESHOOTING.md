# Notification Troubleshooting Guide

## Notification Not Appearing? Follow These Steps

### Step 1: Check Notification Status

1. Open the app
2. Go to **Settings**
3. Tap **"Check Notification Status"**
4. This will show you:
   - ✅ Notifications Enabled: Yes/No
   - ✅ Exact Alarms Enabled: Yes/No
   - 📋 Pending Notifications: X

### Step 2: Test Immediate Notification First

Before testing scheduled notifications, verify the basic system works:

1. Go to **Settings**
2. Tap **"Test Notification (Immediate)"**
3. You should see a notification **immediately**

**If immediate notification doesn't work:**
- ❌ Notification permission is denied
- ❌ Notification channel is blocked
- ❌ Do Not Disturb is blocking notifications

**Fix:**
- Settings > Apps > BillManager > Notifications > **Turn ON**
- Settings > Apps > BillManager > Notifications > Bill Reminders > **Turn ON**
- Turn off Do Not Disturb mode

### Step 3: Check Permissions

#### Android 13+ Permissions Required

1. **Notification Permission**
   - Settings > Apps > BillManager > Notifications
   - Make sure it's **ON**

2. **Exact Alarm Permission** (Android 12+)
   - Settings > Apps > BillManager > Alarms & reminders
   - Enable "Allow setting alarms and reminders"
   - This is REQUIRED for scheduled notifications!

3. **Battery Optimization**
   - Settings > Apps > BillManager > Battery
   - Set to "Unrestricted" or "Optimized" (NOT "Restricted")

### Step 4: Test Scheduled Notification

Once immediate notifications work:

1. Go to **Settings**
2. Tap **"Test Scheduled Notification"**
3. **Close the app completely** (swipe away from recent apps)
4. Wait 10 seconds
5. Notification should appear

**Check the logs in your terminal:**
```
flutter logs
```

Look for:
```
🧪 Starting test notification scheduling...
📱 Notifications enabled: true
⏰ Can schedule exact alarms: true
✅ Test notification scheduled successfully!
📋 Total pending notifications: 1
```

### Step 5: Verify Pending Notifications

1. Go to **Settings**
2. Tap **"View Scheduled Notifications"**
3. You should see your test notification listed

**If list is empty:**
- Notification wasn't scheduled (check logs for errors)
- Permission was denied
- Exact alarm permission not granted

### Common Issues & Solutions

#### Issue 1: "Notifications enabled: false"

**Solution:**
```
Settings > Apps > BillManager > Notifications > Turn ON
```

Or tap "Request Permissions" in the status dialog.

#### Issue 2: "Exact alarms: false" (Android 12+)

**Solution:**
```
Settings > Apps > BillManager > Alarms & reminders
Enable "Allow setting alarms and reminders"
```

This is CRITICAL for scheduled notifications!

#### Issue 3: Immediate works, scheduled doesn't

**Causes:**
- Exact alarm permission not granted
- Battery optimization killing the scheduler
- Do Not Disturb blocking scheduled notifications

**Solution:**
1. Grant exact alarm permission (see Issue 2)
2. Disable battery optimization:
   ```
   Settings > Apps > BillManager > Battery > Unrestricted
   ```
3. Check Do Not Disturb settings:
   ```
   Settings > Sound > Do Not Disturb
   Make sure it allows notifications from BillManager
   ```

#### Issue 4: Notification appears late

**Cause:** Android battery optimization delaying delivery

**Solution:**
```
Settings > Apps > BillManager > Battery > Unrestricted
```

#### Issue 5: No notification after phone reboot

**Cause:** Notifications need to be rescheduled after reboot

**Solution:**
- Open the app once after reboot
- App will automatically reschedule all notifications
- This is normal behavior for flutter_local_notifications

### Debug Checklist

Run through this checklist:

- [ ] Immediate notification works
- [ ] Notification permission granted
- [ ] Exact alarm permission granted (Android 12+)
- [ ] Battery optimization set to Unrestricted
- [ ] Do Not Disturb is off or allows BillManager
- [ ] Notification channel "Bill Reminders" is enabled
- [ ] Pending notifications list shows scheduled notification
- [ ] Console logs show "✅ Test notification scheduled successfully!"

### Reading Console Logs

Connect your phone via USB and run:
```bash
flutter logs
```

**Good logs (working):**
```
🧪 Starting test notification scheduling...
📱 Notifications enabled: true
⏰ Can schedule exact alarms: true
⏰ Current time: 2025-10-25 14:30:00.000
⏰ Scheduled time: 2025-10-25 14:30:10.000
🔔 Scheduling notification:
   ID: 999999
   Title: Test Notification
✅ Test notification scheduled successfully!
📋 Total pending notifications: 1
   - ID: 999999, Title: Test Notification
```

**Bad logs (not working):**
```
🧪 Starting test notification scheduling...
📱 Notifications enabled: false
⚠️ Notifications not enabled! Requesting permission...
📱 Permission granted: false
❌ Permission denied! Cannot schedule notification.
```

Or:
```
🧪 Starting test notification scheduling...
📱 Notifications enabled: true
⏰ Can schedule exact alarms: false
⚠️ Exact alarm permission not granted!
```

### Still Not Working?

If you've tried everything above and it still doesn't work:

1. **Uninstall and reinstall the app**
   - This resets all permissions
   - Grant all permissions when prompted

2. **Check Android version**
   - Android 12+ requires exact alarm permission
   - Android 13+ requires notification permission at runtime

3. **Check phone manufacturer restrictions**
   - Some manufacturers (Xiaomi, Huawei, Oppo) have aggressive battery optimization
   - Look for "Autostart" or "Background activity" settings
   - Enable for BillManager

4. **Test on another device**
   - If it works on another device, it's a device-specific issue
   - Check manufacturer-specific settings

### Manufacturer-Specific Settings

#### Xiaomi/MIUI
```
Settings > Apps > Manage apps > BillManager
- Autostart: ON
- Battery saver: No restrictions
- Display pop-up windows while running in background: ON
```

#### Huawei/EMUI
```
Settings > Apps > BillManager
- Launch: Manage manually
  - Auto-launch: ON
  - Secondary launch: ON
  - Run in background: ON
```

#### Oppo/ColorOS
```
Settings > Apps > BillManager
- Startup manager: Enable
- Background freeze: Disable
```

#### Samsung/One UI
```
Settings > Apps > BillManager
- Battery > Optimize battery usage: OFF
- Sleeping apps: Remove BillManager if listed
```

### Success Indicators

You'll know it's working when:

✅ Immediate test notification appears instantly
✅ "Check Notification Status" shows all green
✅ "View Scheduled Notifications" shows your test notification
✅ Console logs show "✅ Test notification scheduled successfully!"
✅ After 10 seconds (with app closed), notification appears

### Need More Help?

If you're still having issues:

1. Share your console logs (flutter logs output)
2. Share your "Check Notification Status" screenshot
3. Mention your Android version and phone model
4. Describe exactly what happens (or doesn't happen)

---

**Remember:** The most common issue is missing the "Exact Alarms" permission on Android 12+. Make sure to grant it!
