import '../models/bill_hive.dart';
import '../models/notification_hive.dart';
import '../services/offline_first_notification_service.dart';
import '../services/hive_service.dart';

class BillStatusHelper {
  static String calculateStatus(BillHive bill) {
    if (bill.isPaid) {
      return 'paid';
    }

    final now = DateTime.now();

    // CRITICAL FIX: All bills now use consistent date + reminder time logic
    // This ensures bills only become "overdue" at their reminder time, not at midnight

    // Compare dates first
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(bill.dueAt.year, bill.dueAt.month, bill.dueAt.day);

    // If due date is in the future, bill is upcoming
    if (today.isBefore(dueDate)) {
      return 'upcoming';
    }

    // If due date is in the past, bill is overdue
    if (today.isAfter(dueDate)) {
      return 'overdue';
    }

    // Due date is TODAY - check reminder time to determine status
    // Default to 9:00 AM if no notification time is set
    final reminderTime = bill.notificationTime ?? '09:00';
    final reminderParts = reminderTime.split(':');
    final reminderHour = int.parse(reminderParts[0]);
    final reminderMinute = int.parse(reminderParts[1]);

    final reminderDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminderHour,
      reminderMinute,
    );

    // Bill is upcoming if we haven't reached reminder time yet
    // Bill becomes overdue AT or AFTER reminder time
    if (now.isBefore(reminderDateTime)) {
      return 'upcoming';
    }

    return 'overdue';
  }

  static DateTime getOverdueTime(BillHive bill) {
    // CRITICAL FIX: Consistent with calculateStatus() logic
    // All bills become overdue at their reminder time on the due date

    // Use reminder time (default to 9:00 AM if not set)
    final reminderTime = bill.notificationTime ?? '09:00';
    final reminderParts = reminderTime.split(':');
    final reminderHour = int.parse(reminderParts[0]);
    final reminderMinute = int.parse(reminderParts[1]);

    return DateTime(
      bill.dueAt.year,
      bill.dueAt.month,
      bill.dueAt.day,
      reminderHour,
      reminderMinute,
    );
  }

  /// Create notification if bill became overdue
  /// Called automatically when status is calculated
  static Future<void> checkAndCreateNotification(BillHive bill) async {
    final status = calculateStatus(bill);

    // Create notification for overdue bills
    if (status == 'overdue' && !bill.isPaid) {
      await OfflineFirstNotificationService.createNotification(
        billId: bill.id,
        billTitle: bill.title,
        type: NotificationType.overdue,
        scheduledFor: bill.dueAt,
        isRecurring: bill.repeat != 'none',
        recurringSequence: bill.recurringSequence,
        repeatCount: bill.repeatCount,
        amount: bill.amount,
        vendor: bill.vendor,
      );
    }
  }

  /// Sync all bills and create missing notifications
  /// Called after login or bill sync to regenerate notification history
  static Future<void> syncAllBillNotifications(List<BillHive> bills) async {
    for (final bill in bills) {
      if (bill.isPaid || bill.isDeleted) continue;

      final status = calculateStatus(bill);

      // Create notification based on status
      if (status == 'overdue') {
        await OfflineFirstNotificationService.createNotification(
          billId: bill.id,
          billTitle: bill.title,
          type: NotificationType.overdue,
          scheduledFor: bill.dueAt,
          isRecurring: bill.repeat != 'none',
          recurringSequence: bill.recurringSequence,
          repeatCount: bill.repeatCount,
          amount: bill.amount,
          vendor: bill.vendor,
          skipDeviceNotification:
              true, // Don't send device notifications for missed bills
        );
      }
    }
  }

  /// Catch up on missed notifications (called on login/app open)
  /// This ensures notification history is complete even if user was logged out
  static Future<void> catchUpMissedNotifications(String userId) async {
    try {
      final bills = HiveService.getBillsForUser(userId);
      final now = DateTime.now();

      for (final bill in bills) {
        if (bill.isPaid || bill.isDeleted) continue;

        // Check if bill's reminder time has passed (OVERDUE only)
        final overdueTime = getOverdueTime(bill);

        if (now.isAfter(overdueTime)) {
          // Bill is overdue - create notification
          // (occurrenceId will prevent duplicates if it already exists)
          await OfflineFirstNotificationService.createNotification(
            billId: bill.id,
            billTitle: bill.title,
            type: NotificationType.overdue,
            scheduledFor: bill.dueAt,
            isRecurring: bill.repeat != 'none',
            recurringSequence: bill.recurringSequence,
            repeatCount: bill.repeatCount,
            amount: bill.amount,
            vendor: bill.vendor,
          );
        }
        // REMOVED: No notification for "due today" or upcoming bills
      }

      print('✅ Caught up on missed notifications for ${bills.length} bills');
    } catch (e) {
      print('⚠️ Error catching up on notifications: $e');
    }
  }
}
