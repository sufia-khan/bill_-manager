import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill_hive.dart';

/// Helper class for Hive database migrations and data recovery
class HiveMigrationHelper {
  /// Clear all Hive data (use with caution - for development/debugging only)
  /// This will delete all local bills and sync queue data
  static Future<void> clearAllHiveData() async {
    try {
      // Close all boxes first
      await Hive.close();

      // Delete all boxes
      await Hive.deleteBoxFromDisk('bills');
      await Hive.deleteBoxFromDisk('sync_queue');

      print('✅ All Hive data cleared successfully');
    } catch (e) {
      print('❌ Error clearing Hive data: $e');
      rethrow;
    }
  }

  /// Validate and repair corrupted bills data
  /// Returns the number of bills that were repaired or removed
  static Future<int> validateAndRepairBills() async {
    try {
      final box = await Hive.openBox<BillHive>('bills');
      int repairedCount = 0;
      final keysToDelete = <dynamic>[];

      for (var key in box.keys) {
        try {
          final bill = box.get(key);
          if (bill == null) {
            keysToDelete.add(key);
            continue;
          }

          // Validate required fields
          if (bill.id.isEmpty ||
              bill.title.isEmpty ||
              bill.vendor.isEmpty ||
              bill.category.isEmpty) {
            keysToDelete.add(key);
            repairedCount++;
          }
        } catch (e) {
          print('Error reading bill at key $key: $e');
          keysToDelete.add(key);
          repairedCount++;
        }
      }

      // Delete corrupted entries
      for (var key in keysToDelete) {
        await box.delete(key);
      }

      print('✅ Validated bills: $repairedCount corrupted entries removed');
      return repairedCount;
    } catch (e) {
      print('❌ Error validating bills: $e');
      return 0;
    }
  }

  /// Get Hive database statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final billsBox = await Hive.openBox<BillHive>('bills');

      return {
        'totalBills': billsBox.length,
        'boxPath': billsBox.path,
        'isOpen': billsBox.isOpen,
      };
    } catch (e) {
      print('❌ Error getting database stats: $e');
      return {'error': e.toString()};
    }
  }
}
