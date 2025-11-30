import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'firebase_service.dart';

class SyncService {
  static const String lastSyncKey = 'last_sync_time';
  static Timer? _syncTimer;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  // Start periodic sync (every 15 minutes to reduce Firestore costs)
  // Bills are synced immediately when added/updated, this is just for backup
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncBills();
    });

    // Also listen for connectivity changes
    _startConnectivityListener();
  }

  // Stop periodic sync
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  // Listen for connectivity changes and sync when back online
  static void _startConnectivityListener() {
    _connectivitySubscription?.cancel();

    bool wasOffline = false;

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isNowOnline = !result.contains(ConnectivityResult.none);

      if (!isNowOnline) {
        wasOffline = true;
        print('📴 Network disconnected');
      } else if (wasOffline) {
        // Just came back online
        wasOffline = false;
        print('📡 Network reconnected - syncing bills immediately...');

        // Sync immediately when reconnecting (with small delay for connection to stabilize)
        Future.delayed(const Duration(seconds: 2), () {
          syncBills();
        });
      }
    });
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
    print('\n🔄 ========== SYNC STARTED ==========');
    print('⏰ Time: ${DateTime.now()}');

    // Prevent concurrent syncs
    if (_isSyncing) {
      print('⚠️ Sync already in progress, skipping');
      print('========================================\n');
      return;
    }

    if (!await isOnline()) {
      print('📴 Device is offline, skipping sync');
      print('========================================\n');
      return;
    }

    if (FirebaseService.currentUserId == null) {
      print('❌ User not authenticated, skipping sync');
      print('========================================\n');
      return;
    }

    print('👤 User ID: ${FirebaseService.currentUserId}');
    _isSyncing = true;

    try {
      // Step 1: Push local changes to server (WRITES)
      print('\n📤 STEP 1: Pushing local changes...');
      final pushedCount = await _pushLocalChanges();

      // Step 2: Pull server changes only if we pushed something
      // This reduces unnecessary reads - delta sync handles the rest
      if (pushedCount > 0) {
        print('\n📥 STEP 2: Pulling server changes...');
        await _pullServerChanges();
      } else {
        print('\n⏭️ STEP 2: Skipped (no changes to push)');
      }

      // Step 3: Update last sync time
      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      if (pushedCount > 0) {
        print('\n✅ Sync completed successfully: pushed $pushedCount bills');
      } else {
        print('\n✅ Sync completed: everything up to date');
      }
    } catch (e) {
      print('\n❌ Sync failed: $e');
      print('Stack trace: ${StackTrace.current}');
    } finally {
      _isSyncing = false;
      print('========================================\n');
    }
  }

  // Push local changes to Firebase - returns count of pushed bills
  static Future<int> _pushLocalChanges() async {
    print('🔍 Checking for bills needing sync...');
    final billsNeedingSync = HiveService.getBillsNeedingSync();

    if (billsNeedingSync.isEmpty) {
      print('✅ No bills need syncing');
      return 0;
    }

    print('📤 Found ${billsNeedingSync.length} bills to sync:');
    for (var bill in billsNeedingSync) {
      print('   - ${bill.title} (${bill.id})');
    }

    try {
      // Sync bills to Firebase using batch write (1 write operation)
      await FirebaseService.syncLocalBillsToServer(billsNeedingSync);
      print('✅ Successfully pushed to Firebase');

      // Mark bills as synced locally
      for (var bill in billsNeedingSync) {
        await HiveService.markBillAsSynced(bill.id);
      }
      print('✅ Marked ${billsNeedingSync.length} bills as synced locally');

      return billsNeedingSync.length;
    } catch (e) {
      print('❌ Error pushing bills to Firebase: $e');
      rethrow;
    }
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
    print('\n🔄 ========== INITIAL SYNC STARTED ==========');

    final currentUserId = FirebaseService.currentUserId;
    final storedUserId = HiveService.getUserData('currentUserId') as String?;

    print('👤 Current User ID: $currentUserId');
    print('💾 Stored User ID: $storedUserId');

    // Check if this is a different user
    final isDifferentUser =
        storedUserId != null && storedUserId != currentUserId;

    print('🔍 Is Different User: $isDifferentUser');

    // If different user, clear old data to prevent data leakage
    if (isDifferentUser) {
      print(
        '⚠️ Different user detected, clearing old local bills to prevent data leakage',
      );
      await HiveService.clearBillsOnly();
      print('🧹 Cleared local bills for new user session');
    }

    // Store current user ID for future checks
    if (currentUserId != null) {
      await HiveService.saveUserData('currentUserId', currentUserId);
    }

    // Check if we're online
    final online = await isOnline();

    if (!online) {
      print('📴 Device is offline');

      // If same user and offline, keep local bills and work offline
      if (!isDifferentUser && storedUserId == currentUserId) {
        final localBills = HiveService.getAllBills();
        print('✅ Working offline with ${localBills.length} local bills');
        print('💾 Changes will sync when back online');
        return;
      } else {
        // New user and offline - no data to show
        print('⚠️ New user login while offline - no bills available');
        return;
      }
    }

    // ONLINE: Push any unsynced bills BEFORE clearing
    // This handles both same user AND first-time user (storedUserId == null)
    if (currentUserId != null && !isDifferentUser) {
      try {
        final unsyncedBills = HiveService.getBillsNeedingSync();
        if (unsyncedBills.isNotEmpty) {
          print(
            '📤 Found ${unsyncedBills.length} unsynced bills, pushing to server...',
          );
          print('   User: $currentUserId (stored: $storedUserId)');

          // CRITICAL: Push to Firebase first
          await FirebaseService.syncLocalBillsToServer(unsyncedBills);
          print('✅ Successfully pushed unsynced bills to Firebase');

          // Mark bills as synced locally
          for (var bill in unsyncedBills) {
            await HiveService.markBillAsSynced(bill.id);
          }
          print('✅ Marked bills as synced locally');
        } else {
          print('✅ No unsynced bills to push');
        }
      } catch (e) {
        print('❌ CRITICAL: Could not push unsynced bills: $e');
        print('⚠️ Keeping local bills to prevent data loss');
        // DON'T clear local bills if push failed - data would be lost!
        return;
      }
    }

    // ONLINE: Pull server data and MERGE with local (don't clear!)
    try {
      print('📥 Fetching bills from Firebase...');
      // Get all bills from server for the current user
      final serverBills = await FirebaseService.getAllBills();
      print('✅ Fetched ${serverBills.length} bills from Firebase');

      // Get current local bills
      final localBills = HiveService.getAllBills();
      print('📱 Current local bills: ${localBills.length}');

      // MERGE strategy: Update/add server bills without clearing local
      // This preserves any bills that were just added locally
      for (var serverBill in serverBills) {
        final localBill = HiveService.getBillById(serverBill.id);

        if (localBill == null) {
          // New bill from server - add it
          await HiveService.saveBill(serverBill.copyWith(needsSync: false));
        } else if (!localBill.needsSync) {
          // Local bill doesn't need sync - server version is authoritative
          await HiveService.saveBill(serverBill.copyWith(needsSync: false));
        } else {
          // Local bill needs sync - keep local version (will sync later)
          print('⏭️ Keeping local version of ${localBill.title} (needs sync)');
        }
      }
      print('💾 Merged ${serverBills.length} bills from Firebase');

      // Update last sync time
      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      print(
        '✅ Initial sync completed: ${serverBills.length} bills loaded for user $currentUserId',
      );
      print('========================================\n');
    } catch (e) {
      print('❌ Initial sync failed: $e');
      print('💾 Will continue with local data if available');
      print('========================================\n');
    }
  }

  // Force sync now
  static Future<void> forceSyncNow() async {
    await syncBills();
  }
}
