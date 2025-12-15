import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_hive.dart';
import 'firebase_service.dart';
// NOTE: device_id_service.dart and notification_service.dart imports removed
// Device notifications are now handled ONLY by native AlarmReceiver

/// Offline-first notification service
///
/// All notifications stored locally in Hive for instant access.
/// Zero Firestore operations - notifications derived from bill sync.
class OfflineFirstNotificationService {
  static const String _boxName = 'notifications';
  static Box<NotificationHive>? _box;

  /// Initialize the service and open Hive box
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<NotificationHive>(_boxName);
      debugPrint('✅ Notification box opened');
    } else {
      _box = Hive.box<NotificationHive>(_boxName);
    }
  }

  /// Generate unique occurrenceId for deduplication
  ///
  /// Non-recurring: billId
  /// Recurring: billId_scheduledDateTime (ISO 8601)
  static String generateOccurrenceId(String billId, DateTime? scheduledFor) {
    if (scheduledFor == null) {
      return billId; // Non-recurring bill
    }
    return '${billId}_${scheduledFor.toIso8601String()}'; // Recurring bill
  }

  /// Create notification (local Hive only, NO Firestore)
  ///
  /// Returns true if created, false if duplicate
  /// Set skipDeviceNotification to true for missed/historical notifications
  static Future<bool> createNotification({
    required String billId,
    required String billTitle,
    required NotificationType type,
    required DateTime scheduledFor,
    String? userId,
    bool isRecurring = false,
    int? recurringSequence,
    int? repeatCount,
    double? amount,
    String? vendor,
    bool skipDeviceNotification =
        false, // For missed notifications - don't send device alert
  }) async {
    try {
      await init();
      if (_box == null) return false;

      userId ??= FirebaseService.currentUserId;
      if (userId == null) return false;

      // Generate occurrenceId for deduplication
      final occurrenceId = generateOccurrenceId(
        billId,
        isRecurring ? scheduledFor : null,
      );

      // Check if notification already exists (LOCAL check only)
      final exists = _box!.values.any((n) => n.occurrenceId == occurrenceId);

      if (exists) {
        debugPrint('⏭️ Notification already exists: $occurrenceId');
        return false; // Duplicate detected
      }

      // Create notification in Hive
      final notification = NotificationHive(
        id: const Uuid().v4(),
        occurrenceId: occurrenceId,
        billId: billId,
        billTitle: billTitle,
        type: type.displayName,
        title: _generateTitle(billTitle, type),
        message: _generateMessage(billTitle, type, amount, scheduledFor),
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        isRecurring: isRecurring,
        recurringSequence: recurringSequence,
        repeatCount: repeatCount,
        seen: false,
        userId: userId,
      );

      await _box!.add(notification);
      debugPrint('✅ Notification created in Hive: $occurrenceId');

      // REMOVED: Device notifications are now handled ONLY by native AlarmReceiver
      // This prevents duplicate notifications - one from Flutter and one from native
      // This service only saves to Hive history for the notification screen display
      debugPrint(
        '📱 Notification saved to history (device notification via AlarmReceiver only)',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating notification: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get all notifications for current user
  static List<NotificationHive> getNotifications({String? userId}) {
    if (_box == null || !_box!.isOpen) return [];

    userId ??= FirebaseService.currentUserId;
    if (userId == null) return [];

    final notifications = _box!.values.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));

    return notifications;
  }

  /// Mark notification as seen (local only)
  static Future<void> markAsSeen(String notificationId) async {
    if (_box == null) return;

    try {
      final notification = _box!.values.firstWhere(
        (n) => n.id == notificationId,
      );
      notification.seen = true;
      await notification.save();
    } catch (e) {
      debugPrint('Notification not found: $notificationId');
    }
  }

  /// Mark all notifications as seen
  static Future<void> markAllAsSeen({String? userId}) async {
    if (_box == null) return;

    userId ??= FirebaseService.currentUserId;
    if (userId == null) return;

    final notifications = _box!.values.where((n) => n.userId == userId);

    for (final notification in notifications) {
      if (!notification.seen) {
        notification.seen = true;
        await notification.save();
      }
    }
  }

  /// Clean up old notifications (keep last 90 days)
  static Future<int> cleanupOldNotifications({int daysToKeep = 90}) async {
    if (_box == null) return 0;

    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    final toDelete = <dynamic>[];

    for (final notification in _box!.values) {
      if (notification.createdAt.isBefore(cutoff)) {
        toDelete.add(notification.key);
      }
    }

    await _box!.deleteAll(toDelete);
    debugPrint('🧹 Cleaned up ${toDelete.length} old notifications');

    return toDelete.length;
  }

  /// Clear all notifications for a user (e.g., on logout)
  static Future<void> clearAllForUser({String? userId}) async {
    if (_box == null) return;

    userId ??= FirebaseService.currentUserId;
    if (userId == null) return;

    final toDelete = <dynamic>[];

    for (final notification in _box!.values) {
      if (notification.userId == userId) {
        toDelete.add(notification.key);
      }
    }

    await _box!.deleteAll(toDelete);
    debugPrint('🗑️ Cleared ${toDelete.length} notifications for user');
  }

  /// Delete specific notifications by ID
  static Future<void> deleteNotifications(List<String> ids) async {
    if (_box == null) return;

    final toDelete = <dynamic>[];

    for (final notification in _box!.values) {
      if (ids.contains(notification.id)) {
        toDelete.add(notification.key);
      }
    }

    if (toDelete.isNotEmpty) {
      await _box!.deleteAll(toDelete);
      debugPrint('🗑️ Deleted ${toDelete.length} selected notifications');
    }
  }

  /// Get unread notification count
  static int getUnreadCount({String? userId}) {
    if (_box == null) return 0;

    userId ??= FirebaseService.currentUserId;
    if (userId == null) return 0;

    return _box!.values.where((n) => n.userId == userId && !n.seen).length;
  }

  // ==================== HELPER METHODS ====================

  // NOTE: _sendDeviceNotification and _getBill were removed - device notifications
  // are now handled ONLY by native AlarmReceiver to prevent duplicates

  /// Generate notification title based on type
  static String _generateTitle(String billTitle, NotificationType type) {
    switch (type) {
      case NotificationType.due:
        return '$billTitle Overdue'; // Changed from "Due Today" - only overdue notifications
      case NotificationType.overdue:
        return '$billTitle Overdue';
      case NotificationType.reminder:
        return '$billTitle Reminder';
      case NotificationType.paid:
        return '$billTitle Paid';
      case NotificationType.recurringCreated:
        return 'New Bill: $billTitle';
    }
  }

  /// Generate notification message
  static String _generateMessage(
    String billTitle,
    NotificationType type,
    double? amount,
    DateTime date,
  ) {
    final amountStr = amount != null ? '\$${amount.toStringAsFixed(0)}' : '';
    final dateStr = DateFormat('d MMM').format(date);

    switch (type) {
      case NotificationType.due:
        return '$billTitle of $amountStr was due on $dateStr'; // Same as overdue
      case NotificationType.overdue:
        return '$billTitle of $amountStr was due on $dateStr';
      case NotificationType.reminder:
        return '$billTitle of $amountStr is due on $dateStr';
      case NotificationType.paid:
        return 'Payment of $amountStr recorded for $billTitle';
      case NotificationType.recurringCreated:
        return 'New recurring bill created for $dateStr';
    }
  }
}
