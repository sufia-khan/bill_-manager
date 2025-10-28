import '../models/bill_hive.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../widgets/recurring_bill_delete_bottom_sheet.dart';

/// Service for handling recurring bill deletion with three distinct options:
///
/// 1. Delete Only This Occurrence:
///    - Deletes the selected occurrence from database
///    - Cancels notification for this occurrence only
///    - Keeps recurrence rule intact
///    - Remaining bills continue as scheduled
///    - Future bills will still be created automatically
///
/// 2. Delete This and All Future:
///    - Deletes current and all future occurrences
///    - Cancels all related notifications
///    - Stops recurrence from this point forward
///    - Past paid bills remain in history
///
/// 3. Delete Entire Series:
///    - Permanently deletes ALL occurrences (past, current, future)
///    - Cancels all notifications
///    - Complete removal of recurring series
///    - No bills remain in database
class RecurringBillDeleteService {
  /// Delete only this occurrence of a recurring bill
  /// This keeps the recurrence rule intact - future bills will still be created
  static Future<String> deleteThisOccurrence(BillHive bill) async {
    try {
      final box = HiveService.getBillsBox();
      final parentId = bill.parentBillId ?? bill.id;
      final currentSequence = bill.recurringSequence ?? 0;
      final repeatCount = bill.repeatCount;

      // Step 1: Cancel notification for this specific occurrence only
      await NotificationService().cancelBillNotification(bill.id);

      // Step 2: Soft delete this occurrence from the database
      // This marks it as deleted but keeps it in the database for sync purposes
      await HiveService.deleteBill(bill.id);

      // Step 3: Calculate remaining occurrences in the series
      // Count all non-deleted bills in this series with sequence > current
      final futureBills = box.values.where((b) {
        final billParentId = b.parentBillId ?? b.id;
        final billSequence = b.recurringSequence ?? 0;
        return billParentId == parentId &&
            billSequence > currentSequence &&
            !b.isDeleted;
      }).toList();

      final futureBillsCount = futureBills.length;

      // Step 4: Calculate total remaining occurrences (including those not yet created)
      int totalRemaining;
      if (repeatCount != null) {
        // For limited recurrence: total - current sequence
        totalRemaining = repeatCount - currentSequence;
      } else {
        // For unlimited recurrence: show existing future bills + indicate more will come
        totalRemaining = futureBillsCount;
      }

      // Step 5: Generate user-friendly success message
      if (repeatCount != null) {
        // Limited recurrence messages
        if (totalRemaining == 0) {
          return 'Bill deleted successfully. This was the last occurrence.';
        } else if (totalRemaining == 1) {
          return 'This occurrence deleted. 1 occurrence remaining.';
        } else {
          return 'This occurrence deleted. $totalRemaining occurrences remaining.';
        }
      } else {
        // Unlimited recurrence messages
        if (futureBillsCount == 0) {
          return 'This occurrence deleted. Next occurrence will be created automatically.';
        } else if (futureBillsCount == 1) {
          return 'This occurrence deleted. 1 future bill scheduled, more will be created.';
        } else {
          return 'This occurrence deleted. $futureBillsCount future bills scheduled, more will be created.';
        }
      }
    } catch (e) {
      throw Exception('Failed to delete occurrence: $e');
    }
  }

  /// Delete this and all future occurrences
  static Future<String> deleteThisAndFuture(BillHive bill) async {
    try {
      final box = HiveService.getBillsBox();
      final parentId = bill.parentBillId ?? bill.id;
      final currentSequence = bill.recurringSequence ?? 0;

      // Find all bills in this series with sequence >= current
      final billsToDelete = box.values.where((b) {
        final billParentId = b.parentBillId ?? b.id;
        final billSequence = b.recurringSequence ?? 0;
        return billParentId == parentId && billSequence >= currentSequence;
      }).toList();

      // Cancel notifications and delete all future bills
      for (final billToDelete in billsToDelete) {
        await NotificationService().cancelBillNotification(billToDelete.id);
        await HiveService.deleteBill(billToDelete.id);
      }

      // Calculate how many were deleted
      final deletedCount = billsToDelete.length;
      final repeatCount = bill.repeatCount;

      if (repeatCount != null) {
        final remaining = repeatCount - currentSequence;
        if (deletedCount == 1) {
          return 'Bill deleted successfully.';
        } else {
          return 'This and all remaining $remaining occurrences deleted.';
        }
      } else {
        if (deletedCount == 1) {
          return 'Bill deleted. Recurrence stopped.';
        } else {
          return 'This and all future recurring bills deleted. Recurrence stopped.';
        }
      }
    } catch (e) {
      throw Exception('Failed to delete future occurrences: $e');
    }
  }

  /// Delete entire recurring series (all past, current, and future)
  static Future<String> deleteEntireSeries(BillHive bill) async {
    try {
      final box = HiveService.getBillsBox();
      final parentId = bill.parentBillId ?? bill.id;

      // Find all bills in this series
      final billsToDelete = box.values.where((b) {
        final billParentId = b.parentBillId ?? b.id;
        return billParentId == parentId;
      }).toList();

      // Cancel notifications and delete all bills
      for (final billToDelete in billsToDelete) {
        await NotificationService().cancelBillNotification(billToDelete.id);
        await HiveService.deleteBill(billToDelete.id);
      }

      final deletedCount = billsToDelete.length;

      if (deletedCount == 1) {
        return 'Bill deleted successfully.';
      } else {
        return 'Entire recurring series deleted permanently. $deletedCount occurrences removed.';
      }
    } catch (e) {
      throw Exception('Failed to delete entire series: $e');
    }
  }

  /// Main method to handle recurring bill deletion with user choice
  static Future<String> handleRecurringBillDeletion(
    BillHive bill,
    RecurringDeleteOption option,
  ) async {
    switch (option) {
      case RecurringDeleteOption.thisOccurrence:
        return await deleteThisOccurrence(bill);
      case RecurringDeleteOption.thisAndFuture:
        return await deleteThisAndFuture(bill);
      case RecurringDeleteOption.entireSeries:
        return await deleteEntireSeries(bill);
    }
  }
}
