import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';
import '../services/hive_service.dart';
import '../models/sync_status.dart';

/// Provider for managing sync state across the app
/// Tracks online/offline status, pending changes, and sync progress
/// OPTIMIZED: Uses SyncService which only pushes changes (no reads)
class SyncProvider with ChangeNotifier {
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingChanges = 0;
  DateTime? _lastSyncTime;
  int _totalWrites = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingChanges => _pendingChanges;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get totalReads => 0; // We don't track reads anymore (minimized)
  int get totalWrites => _totalWrites;

  SyncProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);

    // Listen to connectivity changes (SyncService handles reconnection sync)
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        print('📡 Network reconnected');
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
      final bill = HiveService.getBillById(billId);
      if (bill == null) {
        return SyncStatus.synced;
      }

      if (bill.needsSync) {
        return SyncStatus.pending;
      }

      return SyncStatus.synced;
    } catch (e) {
      return SyncStatus.synced;
    }
  }

  /// Trigger a sync (PUSH ONLY - no Firestore reads)
  Future<void> triggerSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await SyncService.syncBills();
      _updatePendingChanges();
      _updateSyncStats();
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Force a full sync (USE SPARINGLY - reads from Firestore)
  Future<void> fullSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await SyncService.forceFullSync();
      _updatePendingChanges();
      _updateSyncStats();
    } catch (e) {
      print('Full sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Update pending changes count
  void _updatePendingChanges() {
    _pendingChanges = HiveService.getBillsNeedingSync().length;
    notifyListeners();
  }

  /// Update sync statistics
  void _updateSyncStats() {
    final lastSyncString =
        HiveService.getUserData(SyncService.lastSyncKey) as String?;
    _lastSyncTime = lastSyncString != null
        ? DateTime.tryParse(lastSyncString)
        : null;
    _totalWrites = _pendingChanges;
  }

  /// Mark that a change was made (to update pending count)
  void markChangesMade() {
    _updatePendingChanges();
  }
}
