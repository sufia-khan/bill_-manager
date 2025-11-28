# Firestore Sync - How It Works

## The Problem (Before Fix)
Your bills were saving locally but NOT uploading to Firebase because:
- Bills were saved to Hive (local database) ✅
- But NOT added to the sync queue ❌
- Firebase sync had nothing to upload ❌

## The Solution (After Fix)
Now when you add/update/delete a bill:
1. **Saved to Hive** (local storage) - instant UI update
2. **Added to sync queue** - marked for Firebase upload
3. **Auto-synced every 2 minutes** - uploaded to Firestore in batches

## How to Recover Old Bills
If you have bills that were added before this fix:

1. Open the app
2. Go to **Settings**
3. Find **"Force Sync All Bills"** button (below Sync Status)
4. Tap it and confirm
5. All your local bills will be uploaded to Firebase!

## Optimized for Low Reads/Writes
✅ **Batched writes** - Multiple bills uploaded in one operation
✅ **Debounced sync** - Waits 5 seconds to batch rapid changes
✅ **Delta sync** - Only downloads bills changed since last sync
✅ **Offline-first** - Works without internet, syncs when online
✅ **Periodic sync** - Auto-syncs every 2 minutes (not every second)

## Sync Flow
```
Add Bill → Save to Hive → Add to Sync Queue → Wait 5 seconds → Batch Upload to Firebase
```

## Checking Firestore
After syncing, check Firebase Console:
- Collection: `users/{userId}/bills`
- Each bill should have: id, title, amount, dueAt, etc.

## Troubleshooting
- **Bills not syncing?** Use "Force Sync All Bills" button
- **Still not showing?** Check internet connection
- **Sync failed?** Check Firebase console for errors
