import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'firebase_service.dart';

class SyncService {
  static const String lastSyncKey = 'last_sync_time';
  static Timer? _syncTimer;

  // Start periodic sync (every 15 minutes to reduce Firestore costs)
  // Bills are synced immediately when added/updated, this is just for backup
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncBills();
    });
  }

  // Stop periodic sync
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  // Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // Sync lock to prevent concurrent syncs
  static bool _isSyncing = false;

  // Full sync: Push local changes and pull server changes
  static Future<void> syncBills() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      print('Sync already in progress, skipping');
      return;
    }

    if (!await isOnline()) {
      print('Device is offline, skipping sync');
      return;
    }

    if (FirebaseService.currentUserId == null) {
      print('User not authenticated, skipping sync');
      return;
    }

    _isSyncing = true;
    try {
      // Step 1: Push local changes to server (WRITES)
      final pushedCount = await _pushLocalChanges();

      // Step 2: Pull server changes only if we pushed something
      // This reduces unnecessary reads - delta sync handles the rest
      if (pushedCount > 0) {
        await _pullServerChanges();
      }

      // Step 3: Update last sync time
      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      if (pushedCount > 0) {
        print('Sync completed: pushed $pushedCount bills');
      }
    } catch (e) {
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push local changes to Firebase - returns count of pushed bills
  static Future<int> _pushLocalChanges() async {
    final billsNeedingSync = HiveService.getBillsNeedingSync();

    if (billsNeedingSync.isEmpty) {
      return 0;
    }

    // Sync bills to Firebase using batch write (1 write operation)
    await FirebaseService.syncLocalBillsToServer(billsNeedingSync);

    // Mark bills as synced locally
    for (var bill in billsNeedingSync) {
      await HiveService.markBillAsSynced(bill.id);
    }

    print('📤 Pushed ${billsNeedingSync.length} bills to server');
    return billsNeedingSync.length;
  }

  // Pull server changes to local
  static Future<void> _pullServerChanges() async {
    final lastSyncString = HiveService.getUserData(lastSyncKey) as String?;
    final lastSyncTime = lastSyncString != null
        ? DateTime.parse(lastSyncString)
        : DateTime(2000); // Get all bills if never synced

    final serverBills = await FirebaseService.syncBillsFromServer(lastSyncTime);

    for (var serverBill in serverBills) {
      final localBill = HiveService.getBillById(serverBill.id);

      if (localBill == null) {
        // New bill from server
        await HiveService.saveBill(serverBill.copyWith(needsSync: false));
      } else {
        // Conflict resolution: Server wins if server is newer
        if (serverBill.updatedAt.isAfter(localBill.updatedAt)) {
          await HiveService.saveBill(serverBill.copyWith(needsSync: false));
        }
      }
    }

    print('Pulled ${serverBills.length} bills from server');
  }

  // Initial sync after login
  static Future<void> initialSync() async {
    final currentUserId = FirebaseService.currentUserId;
    final storedUserId = HiveService.getUserData('currentUserId') as String?;

    // SECURITY: Only push unsynced bills if they belong to the SAME user
    // This prevents data leakage if user A's bills are still in local storage
    // and user B logs in - we must NOT push A's bills to B's Firebase!
    if (await isOnline() &&
        currentUserId != null &&
        storedUserId == currentUserId) {
      try {
        final unsyncedBills = HiveService.getBillsNeedingSync();
        if (unsyncedBills.isNotEmpty) {
          print(
            '📤 Found ${unsyncedBills.length} unsynced bills for same user, pushing...',
          );
          await FirebaseService.syncLocalBillsToServer(unsyncedBills);
          print('✅ Pushed unsynced bills to Firebase');
        }
      } catch (e) {
        print('⚠️ Could not push unsynced bills: $e');
        // Continue anyway
      }
    } else if (storedUserId != null && storedUserId != currentUserId) {
      print(
        '⚠️ Different user detected, discarding old local bills to prevent data leakage',
      );
    }

    // ALWAYS clear local bills to prevent data leaking between users
    // This must happen even if offline - better to show no data than wrong data
    await HiveService.clearBillsOnly();
    print('🧹 Cleared local bills for clean user session');

    if (!await isOnline()) {
      print('Device is offline, will sync when online');
      return;
    }

    try {
      // Get all bills from server for the current user
      final serverBills = await FirebaseService.getAllBills();

      // Save to local storage
      for (var bill in serverBills) {
        await HiveService.saveBill(bill.copyWith(needsSync: false));
      }

      // Update last sync time
      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      print(
        'Initial sync completed: ${serverBills.length} bills loaded for user ${FirebaseService.currentUserId}',
      );
    } catch (e) {
      print('Initial sync failed: $e');
    }
  }

  // Force sync now
  static Future<void> forceSyncNow() async {
    await syncBills();
  }
}
