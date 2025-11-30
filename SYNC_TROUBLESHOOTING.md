# Sync Troubleshooting Guide

## How to Manually Sync Bills

### Method 1: Using Settings Screen
1. Open the app
2. Go to **Settings** (bottom navigation)
3. Scroll down to **App** section
4. Tap **"Sync Now"**
5. Wait for confirmation message

### Method 2: Check Console Logs
The app now has detailed sync logging. Check your console/logcat for:

```
🔄 ========== SYNC STARTED ==========
⏰ Time: [timestamp]
👤 User ID: [your-user-id]

📤 STEP 1: Pushing local changes...
🔍 Checking for bills needing sync...
📤 Found X bills to sync:
   - Bill Title (bill-id)
✅ Successfully pushed to Firebase
✅ Marked X bills as synced locally

✅ Sync completed successfully: pushed X bills
========================================
```

## Common Issues & Solutions

### Issue 1: Bill Added Offline Not Syncing

**Symptoms:**
- Bill shows in app
- Bill not in Firebase
- No sync happening

**Check:**
1. Is the device online now?
2. Check console for sync logs
3. Look for "needsSync" flag in bill data

**Solution:**
```dart
// The bill should have needsSync=true when added offline
// Check in console logs or use manual sync button
```

### Issue 2: No Sync Logs Appearing

**Possible Causes:**
- Periodic sync not started
- User not authenticated
- Device offline

**Solution:**
1. Check if user is logged in
2. Check internet connection
3. Use manual "Sync Now" button in Settings

### Issue 3: Sync Says "No bills need syncing"

**This means:**
- All bills already synced
- OR bills don't have needsSync flag

**Debug:**
Check Hive database to see if bill has `needsSync: true`

## Testing Sync Flow

### Test 1: Offline Add & Sync
1. Enable Airplane Mode
2. Add a new bill
3. Verify bill appears in app
4. Disable Airplane Mode
5. Wait 5 seconds or use "Sync Now"
6. Check Firebase - bill should appear
7. Check console logs for sync confirmation

### Test 2: Manual Sync
1. Go to Settings
2. Tap "Sync Now"
3. Should see loading dialog
4. Should see success message
5. Check console for detailed logs

### Test 3: Automatic Sync on Reconnect
1. Enable Airplane Mode
2. Add/edit bills
3. Disable Airplane Mode
4. App should auto-sync within seconds
5. Check console for "Network reconnected - syncing bills..."

## What to Look For in Logs

### Successful Sync:
```
🔄 ========== SYNC STARTED ==========
📤 Found 1 bills to sync:
   - Your Bill Name (abc-123)
✅ Successfully pushed to Firebase
✅ Sync completed successfully: pushed 1 bills
```

### No Changes to Sync:
```
🔄 ========== SYNC STARTED ==========
🔍 Checking for bills needing sync...
✅ No bills need syncing
✅ Sync completed: everything up to date
```

### Offline:
```
🔄 ========== SYNC STARTED ==========
📴 Device is offline, skipping sync
```

### Error:
```
🔄 ========== SYNC STARTED ==========
❌ Sync failed: [error message]
```

## Force Sync from Code

If you need to force sync programmatically:

```dart
// In any widget with access to BillProvider
final billProvider = Provider.of<BillProvider>(context, listen: false);
await billProvider.forceSync();
```

## Verify Bill Has needsSync Flag

To check if a bill is marked for sync:

```dart
final bill = HiveService.getBillById('your-bill-id');
print('Bill needsSync: ${bill?.needsSync}');
```

## Next Steps

1. **Try Manual Sync** - Use the "Sync Now" button in Settings
2. **Check Logs** - Look for the detailed sync logs in console
3. **Verify Firebase** - Check if bill appears in Firestore after sync
4. **Report Issue** - If still not working, share the console logs

## Important Notes

- Sync happens automatically every 15 minutes
- Sync happens when network reconnects
- Sync happens after every bill add/edit/delete
- Manual sync available in Settings
- All syncs are logged to console for debugging
