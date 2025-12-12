import '../models/bill_hive.dart';
import 'hive_service.dart';
import 'user_preferences_service.dart';

class ArchiveManagementService {
  static const int autoDeleteDays = 90;

  /// Check if auto-delete is enabled for current user
  static bool isAutoDeleteEnabled() {
    return UserPreferencesService.getAutoDeleteArchivedBills();
  }

  /// Set auto-delete preference
  static Future<void> setAutoDeleteEnabled(bool enabled) async {
    await UserPreferencesService.setAutoDeleteArchivedBills(enabled);
  }

  /// Toggle pin status for an archived bill
  static Future<void> togglePinStatus(String billId) async {
    final bill = HiveService.getBillById(billId);
    if (bill == null || !bill.isArchived) return;

    final updatedBill = bill.copyWith(
      isPinned: !bill.isPinned,
      needsSync: true,
      updatedAt: DateTime.now(),
      clientUpdatedAt: DateTime.now(),
    );

    await HiveService.saveBill(updatedBill);
  }

  /// Get bills eligible for auto-deletion
  /// [userId] - Optional user ID to filter bills (recommended to prevent cross-account access)
  static List<BillHive> getBillsEligibleForDeletion({String? userId}) {
    if (!isAutoDeleteEnabled()) return [];

    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: autoDeleteDays));

    // CRITICAL FIX: Filter by userId to prevent cross-account auto-deletion
    final allBills = userId != null && userId.isNotEmpty
        ? HiveService.getBillsForUser(userId)
        : HiveService.getAllBills();

    return allBills.where((bill) {
      // Must be archived
      if (!bill.isArchived) return false;

      // Must not be pinned
      if (bill.isPinned) return false;

      // Must have archived date
      if (bill.archivedAt == null) return false;

      // Must be older than 90 days
      return bill.archivedAt!.isBefore(cutoffDate);
    }).toList();
  }

  /// Perform auto-cleanup of old archived bills
  /// [userId] - Optional user ID to filter bills (recommended to prevent cross-account access)
  static Future<int> performAutoCleanup({String? userId}) async {
    if (!isAutoDeleteEnabled()) return 0;

    final eligibleBills = getBillsEligibleForDeletion(userId: userId);
    if (eligibleBills.isEmpty) return 0;

    int deletedCount = 0;

    for (final bill in eligibleBills) {
      try {
        // Mark as deleted in Hive (will sync to Firebase)
        final deletedBill = bill.copyWith(
          isDeleted: true,
          needsSync: true,
          updatedAt: DateTime.now(),
          clientUpdatedAt: DateTime.now(),
        );

        await HiveService.saveBill(deletedBill);
        deletedCount++;

        print(
          '✅ Auto-deleted archived bill: ${bill.title} (archived ${bill.archivedAt})',
        );
      } catch (e) {
        print('❌ Failed to auto-delete bill ${bill.id}: $e');
      }
    }

    return deletedCount;
  }

  /// Get count of bills that will be deleted
  static int getEligibleDeletionCount() {
    return getBillsEligibleForDeletion().length;
  }

  /// Get days until a bill will be auto-deleted
  static int? getDaysUntilDeletion(BillHive bill) {
    if (!bill.isArchived || bill.isPinned || bill.archivedAt == null) {
      return null;
    }

    if (!isAutoDeleteEnabled()) return null;

    final deleteDate = bill.archivedAt!.add(
      const Duration(days: autoDeleteDays),
    );
    final now = DateTime.now();

    if (deleteDate.isBefore(now)) return 0;

    return deleteDate.difference(now).inDays;
  }

  /// Check if a bill is at risk of deletion (less than 7 days)
  static bool isAtRiskOfDeletion(BillHive bill) {
    final days = getDaysUntilDeletion(bill);
    return days != null && days <= 7 && days >= 0;
  }
}
