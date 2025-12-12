import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'hive_service.dart';
import 'firebase_service.dart';
import 'notification_history_service.dart';
import '../models/bill_hive.dart';

/// Callback type for when remote changes are received from Firestore
typedef OnRemoteChangesCallback = void Function();

class SyncService {
  static const String lastSyncKey = 'last_sync_time';
  static const String lastFullSyncKey = 'last_full_sync_time';
  static Timer? _syncTimer;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  // Firestore real-time listener subscription
  static StreamSubscription<QuerySnapshot>? _firestoreSubscription;

  // Callback to notify BillProvider when remote changes are received
  static OnRemoteChangesCallback? _onRemoteChanges;

  // Track if initial sync was done this session (to avoid repeated full syncs)
  static bool _initialSyncDoneThisSession = false;

  // CRITICAL: Track which user the sync service is bound to
  // This prevents syncing data to wrong account after account switch
  static String? _boundUserId;

  /// Set the callback for when remote changes are received.
  /// BillProvider should call this to be notified when Firestore data changes.
  static void setOnRemoteChanges(OnRemoteChangesCallback? callback) {
    _onRemoteChanges = callback;
  }

  /// Start sync service bound to a specific user.
  /// MUST be called after login before any sync operations.
  static void start(String userId) {
    print('🔄 SyncService.start() for user: $userId');
    _boundUserId = userId;
    _initialSyncDoneThisSession = false;
    startPeriodicSync();
    // Start Firestore listener for real-time sync
    startFirestoreListener(userId);
  }

  /// Stop sync service completely.
  /// MUST be called on logout before clearing data.
  static void stop() {
    print('🛑 SyncService.stop() - Clearing user binding');
    _boundUserId = null;
    _initialSyncDoneThisSession = false;
    stopPeriodicSync();
    stopFirestoreListener();
  }

  /// Start listening to Firestore for real-time updates from other devices.
  /// Updates Hive when remote changes occur but does NOT schedule notifications.
  static void startFirestoreListener(String userId) {
    // Cancel any existing subscription
    _firestoreSubscription?.cancel();

    print('👂 Starting Firestore listener for user: $userId');

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bills');

    _firestoreSubscription = collection
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            _handleFirestoreChanges(snapshot, userId);
          },
          onError: (error) {
            print('❌ Firestore listener error: $error');
          },
        );
  }

  /// Stop listening to Firestore changes.
  static void stopFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    print('🔇 Stopped Firestore listener');
  }

  /// Handle changes received from Firestore.
  /// Updates Hive but does NOT trigger notification scheduling.
  static Future<void> _handleFirestoreChanges(
    QuerySnapshot snapshot,
    String userId,
  ) async {
    // Skip if this is the initial snapshot (we handle that in initialSync)
    if (!_initialSyncDoneThisSession) {
      print('⏭️ Ignoring Firestore snapshot - initial sync not done yet');
      return;
    }

    // Validate user binding to prevent data leak
    if (_boundUserId != userId) {
      print('⚠️ Firestore snapshot ignored - user mismatch');
      return;
    }

    print(
      '📡 Received Firestore changes: ${snapshot.docChanges.length} documents',
    );

    bool hasChanges = false;

    for (final docChange in snapshot.docChanges) {
      final data = docChange.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final billId = data['id'] as String?;
      if (billId == null) continue;

      switch (docChange.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          // Check if we already have this bill locally with pending changes
          final localBill = HiveService.getBillById(billId);
          if (localBill != null && localBill.needsSync) {
            // Local changes take priority - don't overwrite
            print('   ↪ Skipping $billId - local changes pending');
            continue;
          }

          // Update Hive with remote data (marking as from server)
          final remoteBill = BillHive.fromFirestore(data);
          final billWithUser = remoteBill.copyWith(
            needsSync: false,
            userId: userId,
          );
          await HiveService.saveBill(billWithUser);

          // CRITICAL: Do NOT mark as local - this is a remote bill
          // Do NOT schedule notifications for remote bills
          print('   ✓ Synced remote bill: ${billWithUser.title}');
          hasChanges = true;
          break;

        case DocumentChangeType.removed:
          // Handle remote deletion
          final localBill = HiveService.getBillById(billId);
          if (localBill != null && !localBill.needsSync) {
            await HiveService.deleteBill(billId);
            print('   ✓ Deleted bill: $billId');
            hasChanges = true;
          }
          break;
      }
    }

    // Notify BillProvider to refresh UI if there were changes
    if (hasChanges && _onRemoteChanges != null) {
      print('📢 Notifying UI of remote changes');
      _onRemoteChanges!();
    }
  }

  /// Validate that sync can proceed for current user.
  /// Returns false and logs warning if user mismatch detected.
  static bool _validateUserBinding() {
    final currentUserId = FirebaseService.currentUserId;

    // No user logged in
    if (currentUserId == null) {
      print('❌ Sync rejected: No user logged in');
      return false;
    }

    // User mismatch - sync bound to different user
    if (_boundUserId != null && _boundUserId != currentUserId) {
      print('⚠️ SYNC REJECTED: User mismatch!');
      print('   Bound to: $_boundUserId');
      print('   Current:  $currentUserId');
      print('   This prevents data leak between accounts.');
      return false;
    }

    return true;
  }

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
    // CRITICAL: Validate user binding to prevent data leak
    if (!_validateUserBinding()) return;

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

    // CRITICAL: Validate user binding to prevent data leak
    if (!_validateUserBinding()) {
      print('========================================\n');
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
