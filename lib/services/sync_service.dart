import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'firebase_service.dart';
import 'notification_history_service.dart';

class SyncService {
  static const String lastSyncKey = 'last_sync_time';
  static const String lastFullSyncKey = 'last_full_sync_time';
  static Timer? _syncTimer;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  // Track if initial sync was done this session (to avoid repeated full syncs)
  static bool _initialSyncDoneThisSession = false;

  // Start periodic sync (every 30 minutes - ONLY pushes local changes, no reads)
  // Full sync only happens on login, not periodically
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      // Only push local changes - NO Firestore reads
      _pushOnlySync();
    });

    // Also listen for connectivity changes
    _startConnectivityListener();
  }

  // Stop periodic sync
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _initialSyncDoneThisSession = false;
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
        print('📡 Network reconnected - pushing local changes...');

        // Only push local changes when reconnecting - NO reads
        Future.delayed(const Duration(seconds: 2), () {
          _pushOnlySync();
        });
      }
    });
  }

  // PUSH-ONLY sync - uploads local changes without reading from Firestore
  // This is the main sync method used for periodic and reconnection syncs
  static Future<void> _pushOnlySync() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;
    if (FirebaseService.currentUserId == null) return;

    _isSyncing = true;
    try {
      final billsNeedingSync = HiveService.getBillsNeedingSync();
      if (billsNeedingSync.isNotEmpty) {
        print('📤 Push-only sync: ${billsNeedingSync.length} bills');
        await FirebaseService.syncLocalBillsToServer(billsNeedingSync);
        for (var bill in billsNeedingSync) {
          await HiveService.markBillAsSynced(bill.id);
        }
        print('✅ Push-only sync completed');
      }
    } catch (e) {
      print('❌ Push-only sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // Sync lock to prevent concurrent syncs
  static bool _isSyncing = false;

  // Sync bills - PUSH ONLY (no Firestore reads)
  // This is called by bill_provider after changes
  static Future<void> syncBills() async {
    print('\n🔄 ========== SYNC (PUSH ONLY) ==========');

    if (_isSyncing) {
      print('⚠️ Sync already in progress, skipping');
      return;
    }

    if (!await isOnline()) {
      print('📴 Device is offline, skipping sync');
      return;
    }

    if (FirebaseService.currentUserId == null) {
      print('❌ User not authenticated, skipping sync');
      return;
    }

    _isSyncing = true;

    try {
      // ONLY push local changes - NO reads from Firestore
      final pushedCount = await _pushLocalChanges();

      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      if (pushedCount > 0) {
        print('✅ Pushed $pushedCount bills to Firebase');
      } else {
        print('✅ No changes to push');
      }
    } catch (e) {
      print('❌ Sync failed: $e');
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

  // Initial sync after login - OPTIMIZED to minimize Firestore reads
  static Future<void> initialSync() async {
    print('\n🔄 ========== INITIAL SYNC ==========');

    final currentUserId = FirebaseService.currentUserId;
    final storedUserId = HiveService.getUserData('currentUserId') as String?;

    print('👤 Current User: $currentUserId');
    print('💾 Stored User: $storedUserId');

    // CRITICAL FIX: Detect user change more robustly
    // Clear bills if:
    // 1. Stored user is different from current user (account switch)
    // 2. Stored user is null BUT there are existing bills (fresh login after logout)
    final existingBills = HiveService.getAllBills(forceRefresh: true);
    final hasPreviousUserData = existingBills.isNotEmpty;

    final isDifferentUser =
        storedUserId != null && storedUserId != currentUserId;
    final isFreshLoginWithStaleData =
        storedUserId == null && hasPreviousUserData && currentUserId != null;

    print('📊 Existing bills: ${existingBills.length}');
    print('🔄 Is different user: $isDifferentUser');
    print('🔄 Is fresh login with stale data: $isFreshLoginWithStaleData');

    // Check if we already did initial sync this session
    if (_initialSyncDoneThisSession &&
        !isDifferentUser &&
        !isFreshLoginWithStaleData) {
      print('⏭️ Initial sync already done this session, skipping');
      print('========================================\n');
      return;
    }

    // CRITICAL: Clear old data if user changed OR if there's stale data from previous user
    if (isDifferentUser || isFreshLoginWithStaleData) {
      print(
        '⚠️ User changed or fresh login with stale data - clearing old bills',
      );
      await HiveService.clearBillsOnly();
      // Also clear notification history to prevent cross-account leak
      await NotificationHistoryService.clearAll();
      print('✅ Old user data cleared');
    }

    // Store current user ID
    if (currentUserId != null) {
      // CRITICAL: Set current user in HiveService to invalidate cache
      HiveService.setCurrentUserId(currentUserId);
      await HiveService.saveUserData('currentUserId', currentUserId);
    }

    // Check if we're online
    final online = await isOnline();

    if (!online) {
      print('📴 Offline - using local data');
      final localBills = HiveService.getAllBills();
      print('✅ ${localBills.length} local bills available');
      print('========================================\n');
      return;
    }

    // STEP 1: Push any unsynced local bills FIRST (WRITES only)
    try {
      final unsyncedBills = HiveService.getBillsNeedingSync();
      if (unsyncedBills.isNotEmpty) {
        print('📤 Pushing ${unsyncedBills.length} unsynced bills...');
        await FirebaseService.syncLocalBillsToServer(unsyncedBills);
        for (var bill in unsyncedBills) {
          await HiveService.markBillAsSynced(bill.id);
        }
        print('✅ Pushed local changes');
      }
    } catch (e) {
      print('⚠️ Push failed: $e - continuing with local data');
    }

    // STEP 2: Only pull from Firestore if:
    // - Different user (need their data)
    // - First time user (no local data)
    // - Haven't synced in 24+ hours
    final shouldPullFromServer =
        isDifferentUser || storedUserId == null || _shouldDoFullSync();

    if (shouldPullFromServer) {
      try {
        print('📥 Pulling bills from Firebase (full sync)...');
        final serverBills = await FirebaseService.getAllBills();
        print('✅ Fetched ${serverBills.length} bills');

        // Merge with local - CRITICAL: Ensure userId is set correctly
        for (var serverBill in serverBills) {
          final localBill = HiveService.getBillById(serverBill.id);
          if (localBill == null || !localBill.needsSync) {
            // CRITICAL FIX: Always set userId to current user to prevent data leak
            final billWithUser = serverBill.copyWith(
              needsSync: false,
              userId: currentUserId, // Ensure userId is set correctly
            );
            await HiveService.saveBill(billWithUser);
          }
        }

        // Update full sync time
        await HiveService.saveUserData(
          lastFullSyncKey,
          DateTime.now().toIso8601String(),
        );
        print('✅ Full sync completed');
      } catch (e) {
        print('⚠️ Pull failed: $e - using local data');
      }
    } else {
      print('⏭️ Skipping full pull (local data is recent)');
    }

    await HiveService.saveUserData(
      lastSyncKey,
      DateTime.now().toIso8601String(),
    );

    _initialSyncDoneThisSession = true;
    print('========================================\n');
  }

  // Check if we should do a full sync (pull from server)
  // Only do full sync once per 24 hours to save reads
  static bool _shouldDoFullSync() {
    final lastFullSyncString =
        HiveService.getUserData(lastFullSyncKey) as String?;
    if (lastFullSyncString == null) return true;

    try {
      final lastFullSync = DateTime.parse(lastFullSyncString);
      final hoursSinceLastSync = DateTime.now()
          .difference(lastFullSync)
          .inHours;
      return hoursSinceLastSync >= 24; // Only full sync once per day
    } catch (e) {
      return true;
    }
  }

  // Force sync now (push only - no reads)
  static Future<void> forceSyncNow() async {
    await syncBills();
  }

  // Force FULL sync (use sparingly - reads from Firestore)
  // Only call this when user explicitly requests a refresh
  static Future<void> forceFullSync() async {
    print('\n🔄 ========== FORCE FULL SYNC ==========');
    if (_isSyncing) return;
    if (!await isOnline()) return;
    if (FirebaseService.currentUserId == null) return;

    _isSyncing = true;
    try {
      // Push first
      final unsyncedBills = HiveService.getBillsNeedingSync();
      if (unsyncedBills.isNotEmpty) {
        await FirebaseService.syncLocalBillsToServer(unsyncedBills);
        for (var bill in unsyncedBills) {
          await HiveService.markBillAsSynced(bill.id);
        }
      }

      // Then pull
      final currentUserId = FirebaseService.currentUserId;
      final serverBills = await FirebaseService.getAllBills();
      for (var serverBill in serverBills) {
        final localBill = HiveService.getBillById(serverBill.id);
        if (localBill == null || !localBill.needsSync) {
          // CRITICAL FIX: Always set userId to prevent data leak
          final billWithUser = serverBill.copyWith(
            needsSync: false,
            userId: currentUserId,
          );
          await HiveService.saveBill(billWithUser);
        }
      }

      await HiveService.saveUserData(
        lastFullSyncKey,
        DateTime.now().toIso8601String(),
      );
      print('✅ Force full sync completed');
    } catch (e) {
      print('❌ Force full sync failed: $e');
    } finally {
      _isSyncing = false;
      print('========================================\n');
    }
  }
}
