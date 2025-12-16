import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/bill_hive.dart';
import '../models/sync_queue_item.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'hive_service.dart';

/// Optimized Firebase Sync Service
/// - Offline-first: All operations save to Hive first
/// - Batched writes: Groups multiple changes into single Firestore batch
/// - Debounced sync: Delays sync to batch rapid changes (5 seconds)
/// - Delta sync: Only fetches bills modified since last sync
/// - Conflict resolution: Last-write-wins based on updatedAt timestamp
/// - Background sync: Auto-syncs when network reconnects
class FirebaseSyncService {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _syncTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;
  String? _userId;
  StreamSubscription? _connectivitySubscription;

  // Sync statistics for monitoring
  int _totalReads = 0;
  int _totalWrites = 0;
  DateTime? _lastSyncTime;

  // Singleton pattern
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  // Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'totalReads': _totalReads,
      'totalWrites': _totalWrites,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'isSyncing': _isSyncing,
    };
  }

  // Initialize sync service
  Future<void> init(String userId) async {
    _userId = userId;
    await _localDb.setUserId(userId);

    // Start periodic sync (every 2 minutes to reduce reads)
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      syncWithFirestore();
    });

    // Initial sync
    await syncWithFirestore();

    // Listen to connectivity changes for background sync
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (!result.contains(ConnectivityResult.none)) {
        print('📡 Network reconnected, triggering sync...');
        triggerSync();
      }
    });
  }

  // Debounced sync trigger (5 seconds to batch rapid changes)
  void triggerSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      syncWithFirestore();
    });
  }

  // Main sync function with optimized batching
  Future<void> syncWithFirestore() async {
    if (_isSyncing || _userId == null) return;

    try {
      _isSyncing = true;

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('📵 Offline - skipping sync');
        return;
      }

      print('🔄 Starting sync...');
      final startTime = DateTime.now();

      // Push local changes (batched)
      final writeCount = await _pushLocalChanges();
      _totalWrites += writeCount;

      // Pull remote changes (delta sync)
      final readCount = await _pullRemoteChanges();
      _totalReads += readCount;

      _lastSyncTime = DateTime.now();
      final duration = _lastSyncTime!.difference(startTime);

      print(
        '✅ Sync complete in ${duration.inMilliseconds}ms '
        '(Reads: $readCount, Writes: $writeCount)',
      );

      // Purge locally deleted bills that have been synced to Firebase
      // This ensures deleted bills don't reappear from stale local data
      final purgedCount = await HiveService.purgeDeletedBills();
      if (purgedCount > 0) {
        print('🧹 Purged $purgedCount deleted bills from local storage');
      }
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push local changes to Firestore with batching
  Future<int> _pushLocalChanges() async {
    final syncQueue = _localDb.getSyncQueue();
    if (syncQueue.isEmpty) return 0;

    print('📤 Pushing ${syncQueue.length} changes...');

    // Firestore batch limit is 500 operations
    const batchSize = 500;
    int totalWrites = 0;
    final itemsToRemove = <SyncQueueItem>[];

    // Process in batches
    for (var i = 0; i < syncQueue.length; i += batchSize) {
      final batchItems = syncQueue.skip(i).take(batchSize).toList();
      final batch = _firestore.batch();
      int batchWrites = 0;

      for (final item in batchItems) {
        try {
          final bill = _localDb.getBill(item.billId);

          // CRITICAL FIX: If bill is null (e.g. cleared during login/cleanup)
          // but operation is 'delete', we MUST still proceed with deletion!
          if (bill == null) {
            if (item.operation == 'delete') {
              print(
                '🗑️ Processing pending delete for missing local bill: ${item.billId}',
              );
              final docRef = _firestore
                  .collection('users')
                  .doc(_userId)
                  .collection('bills')
                  .doc(item.billId);

              batch.delete(docRef);
              batchWrites++;
              itemsToRemove.add(item);
              continue;
            } else {
              // For updates/creates, we need the bill data. If missing, we can't sync.
              itemsToRemove.add(item);
              continue;
            }
          }

          final docRef = _firestore
              .collection('users')
              .doc(_userId)
              .collection('bills')
              .doc(bill.id);

          if (item.operation == 'delete' || bill.isDeleted) {
            batch.delete(docRef);
          } else {
            // Only sync necessary fields to reduce write size
            batch.set(docRef, bill.toFirestore(), SetOptions(merge: true));
          }

          batchWrites++;
          itemsToRemove.add(item);

          // Update local bill sync status
          bill.needsSync = false;
          await bill.save();
        } catch (e) {
          print('⚠️ Error preparing bill ${item.billId}: $e');
          item.retryCount++;
          item.lastAttemptAt = DateTime.now();
          await item.save();

          // Remove from queue after 5 failed attempts
          if (item.retryCount >= 5) {
            print('❌ Giving up on bill ${item.billId} after 5 retries');
            itemsToRemove.add(item);
          }
        }
      }

      // Commit batch
      if (batchWrites > 0) {
        await batch.commit();
        totalWrites += batchWrites;
      }
    }

    // Remove processed items from queue
    for (final item in itemsToRemove) {
      await _localDb.removeSyncQueueItem(item);
    }

    return totalWrites;
  }

  // Pull remote changes from Firestore (delta sync only)
  Future<int> _pullRemoteChanges() async {
    final lastPulledAt = _localDb.getLastPulledAt();

    Query query = _firestore
        .collection('users')
        .doc(_userId)
        .collection('bills')
        .orderBy('updatedAt', descending: false);

    // Delta pull: only get changes since last pull
    if (lastPulledAt != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: lastPulledAt.toIso8601String(),
      );
      print('📥 Fetching changes since ${lastPulledAt.toIso8601String()}');
    } else {
      print('📥 Fetching all bills (first sync)');
    }

    final snapshot = await query.get();
    final now = DateTime.now();

    print('📥 Received ${snapshot.docs.length} changed bills');

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final remoteBill = BillHive.fromFirestore(data);
        final localBill = _localDb.getBill(remoteBill.id);

        // IMPORTANT: Skip deleted bills from server entirely
        // Don't store bills marked as deleted - they should not come back
        if (remoteBill.isDeleted) {
          print('🗑️ Skipping deleted bill from server: ${remoteBill.title}');
          // Cancel any notification that might exist for this bill
          await _notificationService.cancelBillNotification(remoteBill.id);
          // If we have it locally, mark it as deleted too
          if (localBill != null && !localBill.isDeleted) {
            localBill.isDeleted = true;
            localBill.needsSync = false; // Already synced
            await localBill.save();
          }
          continue;
        }

        if (localBill == null) {
          // New bill from server (only store if not deleted)
          await _localDb.billsBox.put(remoteBill.id, remoteBill);

          // Schedule notification if not paid
          if (!remoteBill.isPaid) {
            await _notificationService.scheduleBillNotification(
              remoteBill,
              userId: _userId, // Pass userId
            );
          }
        } else {
          // CRITICAL: Protect local deletions from being overwritten
          // If bill is deleted locally and pending sync, don't let remote restore it
          if (localBill.isDeleted && localBill.needsSync) {
            print(
              '🛡️ Protecting local deletion: ${localBill.title} (pending sync)',
            );
            continue;
          }

          // Conflict resolution: last-write-wins
          if (remoteBill.updatedAt.isAfter(localBill.updatedAt)) {
            // Remote is newer
            print('🔄 Updating bill ${remoteBill.title} (remote newer)');
            await _localDb.billsBox.put(remoteBill.id, remoteBill);

            // Update notification
            if (remoteBill.isDeleted || remoteBill.isPaid) {
              await _notificationService.cancelBillNotification(remoteBill.id);
            } else {
              await _notificationService.scheduleBillNotification(
                remoteBill,
                userId: _userId, // Pass userId
              );
            }
          } else if (localBill.needsSync) {
            // Local is newer and needs sync - will be pushed in next cycle
            print('⏭️ Skipping bill ${localBill.title} (local newer)');
            continue;
          }
        }
      } catch (e) {
        print('⚠️ Error processing remote bill ${doc.id}: $e');
      }
    }

    // Update last pulled timestamp
    await _localDb.setLastPulledAt(now);

    return snapshot.docs.length;
  }

  // Force full sync (for initial login or data recovery)
  Future<void> fullSync() async {
    print('🔄 Starting full sync...');
    await _localDb.setLastPulledAt(DateTime.fromMillisecondsSinceEpoch(0));
    await syncWithFirestore();
  }

  // Check if there are pending changes
  bool hasPendingChanges() {
    return _localDb.getSyncQueue().isNotEmpty;
  }

  // Get pending changes count
  int getPendingChangesCount() {
    return _localDb.getSyncQueue().length;
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
