import 'package:hive/hive.dart';

part 'notification_hive.g.dart';

@HiveType(typeId: 2)
class NotificationHive extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String occurrenceId; // Unique key: billId or billId_scheduledDateTime

  @HiveField(2)
  late String billId;

  @HiveField(3)
  late String billTitle;

  @HiveField(4)
  late String type; // DUE, OVERDUE, REMINDER, PAID

  @HiveField(5)
  late String title;

  @HiveField(6)
  late String message;

  @HiveField(7)
  late DateTime scheduledFor;

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  late bool isRecurring;

  @HiveField(10)
  int? recurringSequence;

  @HiveField(11)
  late bool seen; // Local only, not synced

  @HiveField(12)
  late String userId; // For multi-user filtering

  @HiveField(13)
  int? repeatCount; // Total occurrences for recurring bills

  NotificationHive({
    required this.id,
    required this.occurrenceId,
    required this.billId,
    required this.billTitle,
    required this.type,
    required this.title,
    required this.message,
    required this.scheduledFor,
    required this.createdAt,
    required this.isRecurring,
    this.recurringSequence,
    this.repeatCount,
    this.seen = false,
    required this.userId,
  });

  /// Copy with method for updates
  NotificationHive copyWith({
    String? id,
    String? occurrenceId,
    String? billId,
    String? billTitle,
    String? type,
    String? title,
    String? message,
    DateTime? scheduledFor,
    DateTime? createdAt,
    bool? isRecurring,
    int? recurringSequence,
    int? repeatCount,
    bool? seen,
    String? userId,
  }) {
    return NotificationHive(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      billId: billId ?? this.billId,
      billTitle: billTitle ?? this.billTitle,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringSequence: recurringSequence ?? this.recurringSequence,
      repeatCount: repeatCount ?? this.repeatCount,
      seen: seen ?? this.seen,
      userId: userId ?? this.userId,
    );
  }
}

/// Notification types
enum NotificationType {
  due,
  overdue,
  reminder,
  paid,
  recurringCreated;

  String get displayName {
    switch (this) {
      case NotificationType.due:
        return 'DUE';
      case NotificationType.overdue:
        return 'OVERDUE';
      case NotificationType.reminder:
        return 'REMINDER';
      case NotificationType.paid:
        return 'PAID';
      case NotificationType.recurringCreated:
        return 'RECURRING_CREATED';
    }
  }
}
