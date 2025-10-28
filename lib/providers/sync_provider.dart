import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/firebase_sync_service.dart';
import '../services/local_database_service.dart';
import '../models/sync_status.dart';

/// Provider for managing sync state across the app
/// Tracks online/offline status, pending changes, and sync progress
class SyncProvider with ChangeNotifier {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingChanges = 0;
  DateTime? _lastSyncTime;
  int _totalReads = 0;
  int _totalWrites = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingChanges => _pendingChanges;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get totalReads => _totalReads;
  int get totalWrites => _totalWrites;

  SyncProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        // Just came online - trigger sync
        print('📡 Network reconnected');
        triggerSync();
      } else if (wasOnline && !_isOnline) {
        print('📵 Network disconnected');
      }

      notifyListeners();
    });

    // Update pending changes count
    _updatePendingChanges();
  }

  /// Get sync status for a specific bill
  SyncStatus getBillSyncStatus(String billId) {
    if (!_isOnline) {
      return SyncStatus.offline;
    }

    if (_isSyncing) {
      return SyncStatus.syncing;
    }

    try {
      final bill = _localDb.getBill(billId);
      if (bill == null) {
        return SyncStatus.synced;
      }

      if (bill.needsSync) {
        return SyncStatus.pending;
      }

      return SyncStatus.synced;
    } catch (e) {
      // If database is not initialized yet, return synced status
      return SyncStatus.synced;
    }
  }

  /// Trigger a sync
  Future<void> triggerSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncWithFirestore();
      _updateSyncStats();
      _updatePendingChanges();
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Force a full sync
  Future<void> fullSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.fullSync();
      _updateSyncStats();
      _updatePendingChanges();
    } catch (e) {
      print('Full sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Update pending changes count
  void _updatePendingChanges() {
    _pendingChanges = _syncService.getPendingChangesCount();
    notifyListeners();
  }

  /// Update sync statistics
  void _updateSyncStats() {
    final stats = _syncService.getSyncStats();
    _totalReads = stats['totalReads'] as int;
    _totalWrites = stats['totalWrites'] as int;
    _lastSyncTime = stats['lastSyncTime'] != null
        ? DateTime.parse(stats['lastSyncTime'] as String)
        : null;
  }

  /// Mark that a change was made (to update pending count)
  void markChangesMade() {
    _updatePendingChanges();
  }
}
