import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill_hive.dart';

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

    // Open boxes
    await Hive.openBox<BillHive>(billBoxName);
    await Hive.openBox(userBoxName);
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
  }

  // Get all bills
  static List<BillHive> getAllBills() {
    final box = getBillsBox();
    return box.values.where((bill) => !bill.isDeleted).toList();
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
}
