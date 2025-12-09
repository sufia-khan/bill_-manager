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

  @HiveField(8)
  final String? userId; // Track which user this notification belongs to

  @HiveField(9)
  final bool isHighlighted; // For highlighting when notification is tapped

  NotificationHistory({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.billId,
    this.billTitle,
    this.isRead = false,
    required this.createdAt,
    this.userId, // Add userId parameter
    this.isHighlighted = false,
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
    String? userId,
    bool? isHighlighted,
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
      userId: userId ?? this.userId,
      isHighlighted: isHighlighted ?? this.isHighlighted,
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
      'userId': userId,
      'isHighlighted': isHighlighted,
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
      userId: json['userId'] as String?,
      isHighlighted: json['isHighlighted'] as bool? ?? false,
    );
  }
}
