import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/bill_hive.dart';
import '../models/sync_queue_item.dart';
import 'local_database_service.dart';
import 'notification_service.dart';

class FirebaseSyncService {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _syncTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;
  String? _userId;

  // Singleton pattern
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  // Initialize sync service
  Future<void> init(String userId) async {
    _userId = userId;
    await _localDb.setUserId(userId);

    // Start periodic sync (every 30 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncWithFirestore();
    });

    // Initial sync
    await syncWithFirestore();

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        syncWithFirestore();
      }
    });
  }

  // Debounced sync trigger
  void triggerSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      syncWithFirestore();
    });
  }

  // Main sync function
  Future<void> syncWithFirestore() async {
    if (_isSyncing || _userId == null) return;

    try {
      _isSyncing = true;

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return;
      }

      // Push local changes
      await _pushLocalChanges();

      // Pull remote changes
      await _pullRemoteChanges();
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push local changes to Firestore
  Future<void> _pushLocalChanges() async {
    final syncQueue = _localDb.getSyncQueue();
    if (syncQueue.isEmpty) return;

    // Batch writes for efficiency
    final batch = _firestore.batch();
    final itemsToRemove = <SyncQueueItem>[];

    for (final item in syncQueue) {
      try {
        final bill = _localDb.getBill(item.billId);
        if (bill == null) continue;

        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('bills')
            .doc(bill.id);

        if (item.operation == 'delete' || bill.isDeleted) {
          batch.delete(docRef);
        } else {
          batch.set(docRef, bill.toFirestore(), SetOptions(merge: true));
        }

        // Mark for removal from queue
        itemsToRemove.add(item);

        // Update local bill sync status
        bill.needsSync = false;
        await bill.save();
      } catch (e) {
        print('Error pushing bill ${item.billId}: $e');
        item.retryCount++;
        item.lastAttemptAt = DateTime.now();
        await item.save();

        // Remove from queue after 5 failed attempts
        if (item.retryCount >= 5) {
          itemsToRemove.add(item);
        }
      }
    }

    // Commit batch
    await batch.commit();

    // Remove processed items from queue
    for (final item in itemsToRemove) {
      await _localDb.removeSyncQueueItem(item);
    }
  }

  // Pull remote changes from Firestore
  Future<void> _pullRemoteChanges() async {
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
    }

    final snapshot = await query.get();
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final remoteBill = BillHive.fromFirestore(data);
        final localBill = _localDb.getBill(remoteBill.id);

        if (localBill == null) {
          // New bill from server
          await _localDb.billsBox.put(remoteBill.id, remoteBill);

          // Schedule notification if not paid and not deleted
          if (!remoteBill.isPaid && !remoteBill.isDeleted) {
            await _notificationService.scheduleBillNotification(remoteBill);
          }
        } else {
          // Conflict resolution: last-write-wins
          if (remoteBill.updatedAt.isAfter(localBill.updatedAt)) {
            // Remote is newer
            await _localDb.billsBox.put(remoteBill.id, remoteBill);

            // Update notification
            if (remoteBill.isDeleted || remoteBill.isPaid) {
              await _notificationService.cancelBillNotification(remoteBill.id);
            } else {
              await _notificationService.scheduleBillNotification(remoteBill);
            }
          } else if (localBill.needsSync) {
            // Local is newer and needs sync - will be pushed in next cycle
            continue;
          }
        }
      } catch (e) {
        print('Error processing remote bill ${doc.id}: $e');
      }
    }

    // Update last pulled timestamp
    await _localDb.setLastPulledAt(now);
  }

  // Force full sync (for initial login or data recovery)
  Future<void> fullSync() async {
    await _localDb.setLastPulledAt(DateTime.fromMillisecondsSinceEpoch(0));
    await syncWithFirestore();
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
  }
}
