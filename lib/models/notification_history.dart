import 'package:hive/hive.dart';

part 'notification_history.g.dart';

@HiveType(typeId: 3)
class NotificationHistory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final DateTime sentAt;

  @HiveField(4)
  final String? billId;

  @HiveField(5)
  final String? billTitle;

  @HiveField(6)
  final bool isRead;

  @HiveField(7)
  final DateTime createdAt;

  NotificationHistory({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.billId,
    this.billTitle,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationHistory copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? sentAt,
    String? billId,
    String? billTitle,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationHistory(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      billId: billId ?? this.billId,
      billTitle: billTitle ?? this.billTitle,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'billId': billId,
      'billTitle': billTitle,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationHistory.fromJson(Map<String, dynamic> json) {
    return NotificationHistory(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      billId: json['billId'] as String?,
      billTitle: json['billTitle'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
