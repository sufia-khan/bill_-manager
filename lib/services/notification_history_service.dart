import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_history.dart';

class NotificationHistoryService {
  static const String _boxName = 'notificationHistory';
  static Box<NotificationHistory>? _box;

  // Initialize the service
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<NotificationHistory>(_boxName);
      } else {
        _box = Hive.box<NotificationHistory>(_boxName);
      }
    } catch (e) {
      print('Error initializing notification history service: $e');
    }
  }

  // Add a notification to history
  static Future<void> addNotification({
    required String title,
    required String body,
    String? billId,
    String? billTitle,
  }) async {
    try {
      await init();
      if (_box == null) return;

      final notification = NotificationHistory(
        id: const Uuid().v4(),
        title: title,
        body: body,
        sentAt: DateTime.now(),
        billId: billId,
        billTitle: billTitle,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _box!.put(notification.id, notification);
    } catch (e) {
      print('Error adding notification to history: $e');
    }
  }

  // Get all notifications (sorted by sentAt descending)
  static List<NotificationHistory> getAllNotifications() {
    try {
      if (_box == null || !_box!.isOpen) return [];

      final notifications = _box!.values.toList();
      notifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return notifications;
    } catch (e) {
      print('Error getting all notifications: $e');
      return [];
    }
  }

  // Get paginated notifications
  static List<NotificationHistory> getNotifications({
    int offset = 0,
    int limit = 10,
  }) {
    try {
      final allNotifications = getAllNotifications();
      final endIndex = (offset + limit).clamp(0, allNotifications.length);
      return allNotifications.sublist(
        offset.clamp(0, allNotifications.length),
        endIndex,
      );
    } catch (e) {
      print('Error getting paginated notifications: $e');
      return [];
    }
  }

  // Get total count
  static int getTotalCount() {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      return _box!.length;
    } catch (e) {
      print('Error getting notification count: $e');
      return 0;
    }
  }

  // Get unread count
  static int getUnreadCount() {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      return _box!.values.where((n) => !n.isRead).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String id) async {
    try {
      await init();
      if (_box == null) return;

      final notification = _box!.get(id);
      if (notification != null) {
        final updated = notification.copyWith(isRead: true);
        await _box!.put(id, updated);
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all as read
  static Future<void> markAllAsRead() async {
    try {
      await init();
      if (_box == null) return;

      final notifications = _box!.values.toList();
      for (final notification in notifications) {
        if (!notification.isRead) {
          final updated = notification.copyWith(isRead: true);
          await _box!.put(notification.id, updated);
        }
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a notification
  static Future<void> deleteNotification(String id) async {
    try {
      await init();
      if (_box == null) return;
      await _box!.delete(id);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAll() async {
    try {
      await init();
      if (_box == null) return;
      await _box!.clear();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // Delete old notifications (older than 30 days)
  static Future<void> deleteOldNotifications({int daysToKeep = 30}) async {
    try {
      await init();
      if (_box == null) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final notifications = _box!.values.toList();

      for (final notification in notifications) {
        if (notification.sentAt.isBefore(cutoffDate)) {
          await _box!.delete(notification.id);
        }
      }
    } catch (e) {
      print('Error deleting old notifications: $e');
    }
  }
}
