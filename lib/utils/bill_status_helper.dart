import '../models/bill_hive.dart';

class BillStatusHelper {
  static String calculateStatus(BillHive bill) {
    if (bill.isPaid) {
      return 'paid';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(bill.dueAt.year, bill.dueAt.month, bill.dueAt.day);

    if (today.isBefore(dueDate)) {
      return 'upcoming';
    }

    if (today.isAfter(dueDate)) {
      return 'overdue';
    }

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
