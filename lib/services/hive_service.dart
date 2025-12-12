import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../models/notification_history.dart';

class HiveService {
  static const String billBoxName = 'bills';
  static const String userBoxName = 'user';
  static const String localBillsBoxName =
      'localBills'; // Track bills created on this device
  static const String deviceIdKey = 'deviceId'; // Unique device identifier
  static const String migrationKey =
      'localBillsMigrationDone'; // Migration flag

  // Track current user for data isolation
  static String? _currentUserId;

  /// Set the current user ID. MUST be called on login and before loading bills.
  /// Automatically invalidates the cache if the user changed.
  static void setCurrentUserId(String? userId) {
    if (_currentUserId != userId) {
      print(
        '👤 HiveService: User changed from $_currentUserId to $userId - invalidating cache',
      );
      _invalidateCache();
      _currentUserId = userId;
    }
  }

  /// Get the current user ID
  static String? get currentUserId => _currentUserId;

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BillHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(NotificationHistoryAdapter());
    }

    // Open boxes with error recovery
    try {
      await Hive.openBox<BillHive>(billBoxName);
      await Hive.openBox(userBoxName);
      await Hive.openBox<String>(
        localBillsBoxName,
      ); // For tracking locally-created bills
    } catch (e) {
      print('⚠️ Error opening Hive boxes, attempting recovery: $e');

      // If opening fails due to schema mismatch, clear and recreate
      try {
        // Try to close boxes first if they're partially open
        try {
          if (Hive.isBoxOpen(billBoxName)) {
            await Hive.box<BillHive>(billBoxName).close();
          }
        } catch (_) {}

        try {
          if (Hive.isBoxOpen(userBoxName)) {
            await Hive.box(userBoxName).close();
          }
        } catch (_) {}

        // Delete corrupted boxes
        try {
          await Hive.deleteBoxFromDisk(billBoxName);
        } catch (_) {
          // Ignore if box doesn't exist
        }

        try {
          await Hive.deleteBoxFromDisk(userBoxName);
        } catch (_) {
          // Ignore if box doesn't exist
        }

        try {
          await Hive.deleteBoxFromDisk(localBillsBoxName);
        } catch (_) {
          // Ignore if box doesn't exist
        }

        print('🔄 Cleared corrupted Hive data, recreating boxes...');

        await Hive.openBox<BillHive>(billBoxName);
        await Hive.openBox(userBoxName);
        await Hive.openBox<String>(localBillsBoxName);
        print('✅ Hive boxes recreated successfully');
      } catch (recoveryError) {
        print('❌ Failed to recover Hive boxes: $recoveryError');
        rethrow;
      }
    }
  }

  // Get bills box
  static Box<BillHive> getBillsBox() {
    return Hive.box<BillHive>(billBoxName);
  }

  // Get user box
  static Box? getUserBox() {
    try {
      if (!Hive.isBoxOpen(userBoxName)) return null;
      return Hive.box(userBoxName);
    } catch (e) {
      print('⚠️ getUserBox failed: $e');
      return null;
    }
  }

  // Get local bills tracking box
  static Box<String>? getLocalBillsBox() {
    try {
      if (!Hive.isBoxOpen(localBillsBoxName)) return null;
      return Hive.box<String>(localBillsBoxName);
    } catch (e) {
      print('⚠️ getLocalBillsBox failed: $e');
      return null;
    }
  }

  // ============================================================
  // DEVICE ID & LOCAL BILL TRACKING
  // These methods enable notification isolation per device
  // ============================================================

  /// Get or create a unique device ID.
  /// This ID persists across app restarts but changes on reinstall.
  static String getDeviceId() {
    final userBox = getUserBox();
    if (userBox == null) {
      // Fallback: generate new ID each time if box not available
      return const Uuid().v4();
    }

    String? deviceId = userBox.get(deviceIdKey) as String?;
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      userBox.put(deviceIdKey, deviceId);
      print('📱 Generated new device ID: ${deviceId.substring(0, 8)}...');
    }
    return deviceId;
  }

  /// Mark a bill as locally created on this device.
  /// Only locally-created bills should have notifications scheduled.
  static Future<void> markBillAsLocal(String billId) async {
    final box = getLocalBillsBox();
    if (box == null) return;

    final deviceId = getDeviceId();
    await box.put(billId, deviceId);
    print(
      '📌 Marked bill $billId as local (device: ${deviceId.substring(0, 8)}...)',
    );
  }

  /// Check if a bill was created locally on this device.
  /// Returns true only if the bill was created on THIS specific device.
  static bool isLocalBill(String billId) {
    final box = getLocalBillsBox();
    if (box == null) return false;

    final storedDeviceId = box.get(billId);
    if (storedDeviceId == null) return false;

    final currentDeviceId = getDeviceId();
    return storedDeviceId == currentDeviceId;
  }

  /// Clear all local bill tracking data.
  /// Called on logout to ensure no stale notification state.
  static Future<void> clearLocalBillTracking() async {
    final box = getLocalBillsBox();
    if (box == null) return;

    await box.clear();
    print('🧹 Cleared local bill tracking data');
  }

  /// Check if migration for local bills has been done.
  static bool isLocalBillsMigrationDone() {
    final userBox = getUserBox();
    if (userBox == null) return false;
    return userBox.get(migrationKey) == true;
  }

  /// Mark migration as done.
  static Future<void> markLocalBillsMigrationDone() async {
    final userBox = getUserBox();
    if (userBox == null) return;
    await userBox.put(migrationKey, true);
    print('✅ Local bills migration marked as complete');
  }

  /// One-time migration: Mark all existing Hive bills as local.
  /// This ensures existing users don't lose notifications after the update.
  /// MUST be called BEFORE initial Firestore sync on first run.
  static Future<void> migrateExistingBillsToLocal() async {
    if (isLocalBillsMigrationDone()) {
      print('⏭️ Local bills migration already done, skipping');
      return;
    }

    final billBox = getBillsBox();
    final existingBills = billBox.values.toList();

    if (existingBills.isEmpty) {
      print('📦 No existing bills to migrate');
      await markLocalBillsMigrationDone();
      return;
    }

    print(
      '🔄 Migrating ${existingBills.length} existing bills to local tracking...',
    );

    for (final bill in existingBills) {
      await markBillAsLocal(bill.id);
    }

    await markLocalBillsMigrationDone();
    print(
      '✅ Migration complete: ${existingBills.length} bills marked as local',
    );
  }

  // Add or update bill
  static Future<void> saveBill(BillHive bill) async {
    final box = getBillsBox();
    await box.put(bill.id, bill);
    _invalidateCache();
    print('💾 Saved bill to Hive: ${bill.title} (${bill.id})');
    print('   Total bills in box now: ${box.length}');
  }

  // Get all bills (cached for performance)
  static List<BillHive>? _cachedBills;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(seconds: 5);

  static List<BillHive> getAllBills({bool forceRefresh = false}) {
    final box = getBillsBox();
    final now = DateTime.now();

    // Use cache if valid and not forcing refresh
    if (!forceRefresh &&
        _cachedBills != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheExpiry) {
      // Removed verbose logging - was causing console flood
      return _cachedBills!;
    }

    // Refresh cache
    final allBillsInBox = box.values.toList();
    final nonDeletedBills = allBillsInBox
        .where((bill) => !bill.isDeleted)
        .toList();

    print('📦 Refreshing bill cache:');
    print('   Total in Hive box: ${allBillsInBox.length}');
    print('   Non-deleted: ${nonDeletedBills.length}');

    _cachedBills = nonDeletedBills;
    _cacheTimestamp = now;
    return _cachedBills!;
  }

  // Get bills filtered by user ID - CRITICAL for preventing data leaks
  // This should be the PRIMARY method used by providers to load bills
  static List<BillHive> getBillsForUser(
    String userId, {
    bool forceRefresh = false,
  }) {
    // Safety check: reject if userId is empty
    if (userId.isEmpty) {
      print(
        '⚠️ getBillsForUser called with empty userId - returning empty list',
      );
      return [];
    }

    final allBills = getAllBills(forceRefresh: forceRefresh);
    final userBills = allBills.where((bill) => bill.userId == userId).toList();

    // Debug logging to help track data isolation
    print(
      '📦 Filtered bills for user $userId: ${userBills.length} of ${allBills.length} total',
    );

    // Extra safety: Log any bills that belong to OTHER users (indicates potential data leak)
    final otherUserBills = allBills
        .where((bill) => bill.userId != null && bill.userId != userId)
        .toList();
    if (otherUserBills.isNotEmpty) {
      print(
        '⚠️ WARNING: Found ${otherUserBills.length} bills belonging to OTHER users in local storage!',
      );
      for (var bill in otherUserBills) {
        print(
          '   - "${bill.title}" belongs to user: ${bill.userId?.substring(0, 8)}...',
        );
      }
    }

    return userBills;
  }

  // Invalidate cache when bills are modified
  static void _invalidateCache() {
    _cachedBills = null;
    _cacheTimestamp = null;
  }

  // Get bill by ID
  static BillHive? getBillById(String id) {
    final box = getBillsBox();
    return box.get(id);
  }

  // Delete bill (soft delete)
  static Future<void> deleteBill(String id) async {
    final box = getBillsBox();
    final bill = box.get(id);
    if (bill != null) {
      final updatedBill = bill.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
        clientUpdatedAt: DateTime.now(),
      );
      await box.put(id, updatedBill);
      _invalidateCache();
    }
  }

  // Get bills that need sync - ONLY for current user and non-deleted
  static List<BillHive> getBillsNeedingSync() {
    final box = getBillsBox();
    final currentUserId = _currentUserId;

    return box.values.where((bill) {
      // Must need sync
      if (!bill.needsSync) return false;

      // CRITICAL FIX: Only count bills for current user
      // This prevents showing wrong count on logout
      if (currentUserId != null &&
          bill.userId != null &&
          bill.userId != currentUserId) {
        return false;
      }

      return true;
    }).toList();
  }

  // Mark bill as synced
  static Future<void> markBillAsSynced(String id) async {
    final box = getBillsBox();
    final bill = box.get(id);
    if (bill != null) {
      final updatedBill = bill.copyWith(needsSync: false);
      await box.put(id, updatedBill);
    }
  }

  // Clear all data (for logout) - ENHANCED for complete isolation
  static Future<void> clearAllData() async {
    // Step 1: Clear box contents
    final billBox = getBillsBox();
    final userBox = getUserBox();
    if (userBox != null) {
      // Check if userBox is available
      await billBox.clear();
      await userBox.clear();
      _invalidateCache();

      // Step 2: Close boxes to release any memory references
      await billBox.close();
      await userBox.close();

      // Step 3: Reopen boxes fresh for next session
      // This ensures no stale data remains in memory
      await Hive.openBox<BillHive>(billBoxName);
      await Hive.openBox(userBoxName);
    } else {
      // If userBox was null, we can't clear it, but we can still clear billBox
      await billBox.clear();
      _invalidateCache();
      await billBox.close();
      await Hive.openBox<BillHive>(billBoxName);
      print(
        '⚠️ HiveService.clearAllData() - User box not available, only bill box cleared.',
      );
    }

    // CRITICAL: Clear the current user tracking to prevent data leaks
    _currentUserId = null;
    print(
      '🧹 HiveService.clearAllData() - All data cleared, boxes reopened fresh',
    );
  }

  // Clear only bills data (preserves user settings like currentUserId)
  // SAFETY: Warns if there are unsynced bills
  static Future<void> clearBillsOnly() async {
    // Safety check: warn if clearing bills that need sync
    final unsyncedBills = getBillsNeedingSync();
    if (unsyncedBills.isNotEmpty) {
      print('⚠️⚠️⚠️ WARNING: Clearing ${unsyncedBills.length} unsynced bills!');
      for (var bill in unsyncedBills) {
        print('   - ${bill.title} (${bill.id}) - needsSync: ${bill.needsSync}');
      }
      print('⚠️⚠️⚠️ These bills should have been synced first!');
    }

    final billBox = getBillsBox();
    await billBox.clear();
    _invalidateCache();
    // Note: We DON'T clear _currentUserId here because this method is meant
    // to preserve user context while clearing stale bills (e.g., on user switch)
    print(
      '🧹 HiveService.clearBillsOnly() - Bills cleared, user context preserved',
    );

    // Also clear last sync time so we do a fresh pull
    final userBox = getUserBox();
    if (userBox != null) {
      await userBox.delete('last_sync_time');
    }
  }

  // Hard delete all soft-deleted bills (permanently remove from database)
  static Future<int> purgeDeletedBills() async {
    final box = getBillsBox();
    final deletedBills = box.values.where((bill) => bill.isDeleted).toList();

    int count = 0;
    for (final bill in deletedBills) {
      await box.delete(bill.id);
      count++;
    }

    _invalidateCache();
    print('🧹 Purged $count deleted bills from local storage');
    return count;
  }

  // Debug: Get all bills including deleted ones (for debugging)
  static List<BillHive> getAllBillsIncludingDeleted() {
    final box = getBillsBox();
    return box.values.toList();
  }

  // Debug: Print bill statistics
  static void printBillStats() {
    final box = getBillsBox();
    final allBills = box.values.toList();
    final deletedBills = allBills.where((b) => b.isDeleted).toList();
    final activeBills = allBills.where((b) => !b.isDeleted).toList();
    final recurringBills = activeBills
        .where((b) => b.repeat != 'none')
        .toList();

    print('📊 Bill Statistics:');
    print('   Total in DB: ${allBills.length}');
    print('   Active (not deleted): ${activeBills.length}');
    print('   Soft-deleted: ${deletedBills.length}');
    print('   Recurring (active): ${recurringBills.length}');

    if (deletedBills.isNotEmpty) {
      print('   Deleted bills:');
      for (final bill in deletedBills) {
        print('     - ${bill.title} (${bill.id.substring(0, 8)}...)');
      }
    }
  }

  // Save user data
  static Future<void> saveUserData(String key, dynamic value) async {
    final box = getUserBox();
    if (box != null) {
      await box.put(key, value);
    } else {
      print('⚠️ saveUserData($key) failed: User box not available.');
    }
  }

  // Get user data
  static dynamic getUserData(String key) {
    try {
      final box = getUserBox();
      if (box == null) return null;
      return box.get(key);
    } catch (e) {
      print('⚠️ getUserData($key) failed: $e');
      return null;
    }
  }

  // Migration: Add new fields to existing bills
  static Future<void> migrateExistingBills() async {
    final box = getBillsBox();
    final bills = box.values.toList();

    for (var bill in bills) {
      // Check if migration is needed (if paidAt is null but isPaid is true)
      // This ensures we don't re-migrate already migrated bills
      if (bill.isPaid && bill.paidAt == null) {
        // For paid bills without paidAt, set it to updatedAt as best estimate
        final updatedBill = bill.copyWith(
          paidAt: bill.updatedAt,
          isArchived: false,
          archivedAt: null,
          // parentBillId and recurringSequence remain null for existing bills
        );
        await box.put(bill.id, updatedBill);
      } else if (!bill.isPaid && bill.paidAt == null) {
        // For unpaid bills, ensure new fields have default values
        final updatedBill = bill.copyWith(
          paidAt: null,
          isArchived: false,
          archivedAt: null,
        );
        await box.put(bill.id, updatedBill);
      }
    }
  }

  // Get archived bills
  static List<BillHive> getArchivedBills({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    final box = getBillsBox();
    var bills = box.values
        .where((bill) => bill.isArchived && !bill.isDeleted)
        .toList();

    // Filter by date range if provided
    if (startDate != null) {
      bills = bills
          .where(
            (bill) =>
                bill.paidAt != null &&
                bill.paidAt!.isAfter(
                  startDate.subtract(const Duration(days: 1)),
                ),
          )
          .toList();
    }
    if (endDate != null) {
      bills = bills
          .where(
            (bill) =>
                bill.paidAt != null &&
                bill.paidAt!.isBefore(endDate.add(const Duration(days: 1))),
          )
          .toList();
    }

    // Filter by category if provided
    if (category != null && category.isNotEmpty) {
      bills = bills.where((bill) => bill.category == category).toList();
    }

    // Sort by payment date descending (most recent first)
    bills.sort((a, b) {
      if (a.paidAt == null && b.paidAt == null) return 0;
      if (a.paidAt == null) return 1;
      if (b.paidAt == null) return -1;
      return b.paidAt!.compareTo(a.paidAt!);
    });

    return bills;
  }

  // Get active bills (excluding paid) - optimized
  static List<BillHive> getActiveBills() {
    // Use cached bills if available
    final allBills = getAllBills();
    return allBills.where((bill) => !bill.isPaid).toList();
  }

  // Get paginated archived bills for lazy loading
  static List<BillHive> getArchivedBillsPaginated({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int page = 0,
    int pageSize = 50,
  }) {
    final allArchived = getArchivedBills(
      startDate: startDate,
      endDate: endDate,
      category: category,
    );

    final startIndex = page * pageSize;
    if (startIndex >= allArchived.length) {
      return [];
    }

    final endIndex = (startIndex + pageSize).clamp(0, allArchived.length);
    return allArchived.sublist(startIndex, endIndex);
  }

  // Get count of archived bills (for pagination)
  static int getArchivedBillsCount({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    return getArchivedBills(
      startDate: startDate,
      endDate: endDate,
      category: category,
    ).length;
  }
}
