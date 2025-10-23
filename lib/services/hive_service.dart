import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill_hive.dart';
import '../models/notification_history.dart';
import '../services/notification_history_service.dart';

class HiveService {
  static const String billBoxName = 'bills';
  static const String userBoxName = 'user';

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

        print('🔄 Cleared corrupted Hive data, recreating boxes...');

        await Hive.openBox<BillHive>(billBoxName);
        await Hive.openBox(userBoxName);
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
  static Box getUserBox() {
    return Hive.box(userBoxName);
  }

  // Add or update bill
  static Future<void> saveBill(BillHive bill) async {
    final box = getBillsBox();
    await box.put(bill.id, bill);
    _invalidateCache();
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
      return _cachedBills!;
    }

    // Refresh cache
    _cachedBills = box.values.where((bill) => !bill.isDeleted).toList();
    _cacheTimestamp = now;
    return _cachedBills!;
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

  // Get bills that need sync
  static List<BillHive> getBillsNeedingSync() {
    final box = getBillsBox();
    return box.values.where((bill) => bill.needsSync).toList();
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

  // Clear all data (for logout)
  static Future<void> clearAllData() async {
    final billBox = getBillsBox();
    final userBox = getUserBox();
    await billBox.clear();
    await userBox.clear();
  }

  // Save user data
  static Future<void> saveUserData(String key, dynamic value) async {
    final box = getUserBox();
    await box.put(key, value);
  }

  // Get user data
  static dynamic getUserData(String key) {
    final box = getUserBox();
    return box.get(key);
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
        .where((bill) => bill.isPaid && !bill.isDeleted)
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
