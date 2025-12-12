import '../models/bill_hive.dart';

class BillStatusHelper {
  static String calculateStatus(BillHive bill) {
    if (bill.isPaid) {
      return 'paid';
    }

    final now = DateTime.now();

    // CRITICAL FIX: For 1-minute testing, use exact DateTime comparison
    // This ensures bills become overdue at the exact minute, not just the date
    if (bill.repeat.toLowerCase() == '1 minute (testing)') {
      // For testing mode, compare full DateTime (including time)
      // Bill is overdue if current time >= due time
      if (now.isAfter(bill.dueAt) || now.isAtSameMomentAs(bill.dueAt)) {
        return 'overdue';
      }
      return 'upcoming';
    }

    // For regular recurring bills, use date + reminder time logic
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(bill.dueAt.year, bill.dueAt.month, bill.dueAt.day);

    if (today.isBefore(dueDate)) {
      return 'upcoming';
    }

    if (today.isAfter(dueDate)) {
      return 'overdue';
    }

    // Today equals due date - check reminder time
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

    if (now.isBefore(reminderDateTime)) {
      return 'upcoming';
    }

    return 'overdue';
  }

  static DateTime getOverdueTime(BillHive bill) {
    // CRITICAL FIX: For 1-minute testing, return exact dueAt time
    if (bill.repeat.toLowerCase() == '1 minute (testing)') {
      return bill.dueAt;
    }

    // For regular bills, use reminder time on due date
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
