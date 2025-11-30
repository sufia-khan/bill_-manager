# Test Offline Sync - Step by Step

## The Issue You're Experiencing
Bill added offline → App closed → App reopened → Bill disappeared

## What I Fixed

### Fix 1: Handle First-Time User
**Problem:** When `storedUserId` is null (first time), the condition `storedUserId == currentUserId` was false, so unsynced bills weren't pushed.

**Solution:** Changed to `!isDifferentUser` which handles both same user AND first-time user.

### Fix 2: Added Safety Warnings
**Problem:** Bills were being cleared without warning if they had `needsSync=true`.

**Solution:** Added warning logs when clearing unsynced bills.

### Fix 3: Added Detailed Logging
**Problem:** Hard to debug what's happening during sync.

**Solution:** Added comprehensive logging at every step.

## Test Steps

### Test 1: Add Bill Offline, Close App, Reopen

1. **Enable Airplane Mode**
2. **Open the app** (make sure you're logged in)
3. **Add a new bill:**
   - Title: "Test Offline Bill"
   - Amount: $99.99
   - Category: Any
   - Due date: Tomorrow
4. **Verify bill shows in app** ✓
5. **Close the app completely** (swipe away from recent apps)
6. **Disable Airplane Mode** (turn on WiFi/Data)
7. **Reopen the app**
8. **Check console logs** - you should see:

```
🔄 ========== INITIAL SYNC STARTED ==========
👤 Current User ID: [your-user-id]
💾 Stored User ID: [your-user-id or null]
🔍 Is Different User: false

📤 Found 1 unsynced bills, pushing to server...
   User: [your-user-id] (stored: [your-user-id or null])
✅ Successfully pushed unsynced bills to Firebase
✅ Marked bills as synced locally

📥 Fetching bills from Firebase...
✅ Fetched X bills from Firebase
📱 Current local bills: X
🧹 Cleared local storage
💾 Saved X bills to local storage
✅ Initial sync completed
```

9. **Check Firebase Console** - bill should be there
10. **Check app** - bill should still be visible

### Test 2: What If Sync Fails?

1. **Enable Airplane Mode**
2. **Add a bill**
3. **Close app**
4. **Keep Airplane Mode ON**
5. **Reopen app**
6. **Check console:**

```
📴 Device is offline
✅ Working offline with 1 local bills
💾 Changes will sync when back online
```

7. **Bill should still be visible in app**
8. **Disable Airplane Mode**
9. **Wait 5 seconds** (auto-sync should trigger)
10. **Check console for sync logs**

### Test 3: Manual Sync

1. **Enable Airplane Mode**
2. **Add a bill**
3. **Disable Airplane Mode**
4. **Go to Settings → Sync Now**
5. **Check console logs**
6. **Verify bill in Firebase**

## What to Look For in Console

### ✅ SUCCESS - Bill Synced:
```
🔄 ========== INITIAL SYNC STARTED ==========
👤 Current User ID: abc123
💾 Stored User ID: abc123 (or null for first time)
🔍 Is Different User: false
📤 Found 1 unsynced bills, pushing to server...
✅ Successfully pushed unsynced bills to Firebase
✅ Marked bills as synced locally
📥 Fetching bills from Firebase...
✅ Fetched 5 bills from Firebase
💾 Saved 5 bills to local storage
✅ Initial sync completed
```

### ⚠️ WARNING - Bills Cleared Without Sync:
```
⚠️⚠️⚠️ WARNING: Clearing 1 unsynced bills!
   - Test Bill (bill-id) - needsSync: true
⚠️⚠️⚠️ These bills should have been synced first!
```
**If you see this, it means bills are being lost!**

### ❌ ERROR - Sync Failed:
```
❌ CRITICAL: Could not push unsynced bills: [error]
⚠️ Keeping local bills to prevent data loss
```
**Bills are preserved locally, will retry next time**

### 📴 OFFLINE - Working Offline:
```
📴 Device is offline
✅ Working offline with 1 local bills
💾 Changes will sync when back online
```
**Bills stay in local storage, will sync when online**

## Common Issues & Solutions

### Issue 1: Bill Disappears on App Reopen
**Cause:** Bills cleared before being synced

**Check Console For:**
- "WARNING: Clearing X unsynced bills"
- "CRITICAL: Could not push unsynced bills"

**Solution:**
- Use "Sync Now" button before closing app
- Check if Firebase Auth is ready (currentUserId should not be null)

### Issue 2: Bill Not Syncing to Firebase
**Cause:** Network issues or Firebase errors

**Check Console For:**
- "Device is offline"
- "Could not push unsynced bills"

**Solution:**
- Check internet connection
- Use "Sync Now" button manually
- Check Firebase Console for errors

### Issue 3: Bill Shows in App But Not Firebase
**Cause:** Bill has `needsSync=true` but hasn't synced yet

**Check:**
1. Go to Settings → Sync Now
2. Check console logs
3. Verify bill appears in Firebase

## Debugging Commands

### Check if Bill Has needsSync Flag:
```dart
final bill = HiveService.getBillById('your-bill-id');
print('Bill needsSync: ${bill?.needsSync}');
```

### Check All Unsynced Bills:
```dart
final unsyncedBills = HiveService.getBillsNeedingSync();
print('Unsynced bills: ${unsyncedBills.length}');
for (var bill in unsyncedBills) {
  print('- ${bill.title} (${bill.id})');
}
```

### Force Sync:
```dart
await SyncService.syncBills();
```

## Expected Behavior After Fix

1. ✅ Bills added offline are saved to local storage
2. ✅ Bills persist when app is closed and reopened
3. ✅ Bills sync automatically when network is available
4. ✅ Bills are pushed to Firebase BEFORE local storage is cleared
5. ✅ If sync fails, bills stay in local storage
6. ✅ Warning logs if bills are cleared without syncing
7. ✅ Manual "Sync Now" button works
8. ✅ Network reconnection triggers immediate sync

## Next Steps

1. **Run Test 1** (the main test case)
2. **Share console logs** if bill still disappears
3. **Check for warning messages** about unsynced bills
4. **Verify Firebase Auth** is working (currentUserId not null)

The detailed logging will help us see exactly where the bill is being lost!
