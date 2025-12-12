import '../models/bill_hive.dart';

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
}
