import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'firebase_service.dart';

class SyncService {
  static const String lastSyncKey = 'last_sync_time';
  static Timer? _syncTimer;

  // Start periodic sync (every 5 minutes)
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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

  // Full sync: Push local changes and pull server changes
  static Future<void> syncBills() async {
    if (!await isOnline()) {
      print('Device is offline, skipping sync');
      return;
    }

    if (FirebaseService.currentUserId == null) {
      print('User not authenticated, skipping sync');
      return;
    }

    try {
      // Step 1: Push local changes to server
      await _pushLocalChanges();

      // Step 2: Pull server changes
      await _pullServerChanges();

      // Step 3: Update last sync time
      await HiveService.saveUserData(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      print('Sync completed successfully');
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  // Push local changes to Firebase
  static Future<void> _pushLocalChanges() async {
    final billsNeedingSync = HiveService.getBillsNeedingSync();

    if (billsNeedingSync.isEmpty) {
      return;
    }

    // Sync bills to Firebase
    await FirebaseService.syncLocalBillsToServer(billsNeedingSync);

    // Mark bills as synced
    for (var bill in billsNeedingSync) {
      await HiveService.markBillAsSynced(bill.id);
    }

    print('Pushed ${billsNeedingSync.length} bills to server');
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
    if (!await isOnline()) {
      print('Device is offline, using local data only');
      return;
    }

    try {
      // Get all bills from server
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

      print('Initial sync completed: ${serverBills.length} bills loaded');
    } catch (e) {
      print('Initial sync failed: $e');
    }
  }

  // Force sync now
  static Future<void> forceSyncNow() async {
    await syncBills();
  }
}
