import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_hive.dart';
import '../models/bill_hive.dart';
import 'firebase_service.dart';
import 'device_id_service.dart';
import 'notification_service.dart';

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
  static Future<bool> createNotification({
    required String billId,
    required String billTitle,
    required NotificationType type,
    required DateTime scheduledFor,
    String? userId,
    bool isRecurring = false,
    int? recurringSequence,
    double? amount,
    String? vendor,
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
        title: _generateTitle(type),
        message: _generateMessage(billTitle, type, amount, vendor),
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        isRecurring: isRecurring,
        recurringSequence: recurringSequence,
        seen: false,
        userId: userId,
      );

      await _box!.add(notification);
      debugPrint('✅ Notification created in Hive: $occurrenceId');

      // Send device notification (if this device owns the bill)
      await _sendDeviceNotification(billId, notification);

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

    final notification = _box!.values.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification not found'),
    );

    notification.seen = true;
    await notification.save();
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
  static Future<void> clearAllForUser(String userId) async {
    if (_box == null) return;

    final toDelete = <dynamic>[];

    for (final notification in _box!.values) {
      if (notification.userId == userId) {
        toDelete.add(notification.key);
      }
    }

    await _box!.deleteAll(toDelete);
    debugPrint('🗑️ Cleared ${toDelete.length} notifications for user');
  }

  /// Get unread notification count
  static int getUnreadCount({String? userId}) {
    if (_box == null) return 0;

    userId ??= FirebaseService.currentUserId;
    if (userId == null) return 0;

    return _box!.values.where((n) => n.userId == userId && !n.seen).length;
  }

  // ==================== HELPER METHODS ====================

  /// Send device notification (only if this device owns the bill)
  static Future<void> _sendDeviceNotification(
    String billId,
    NotificationHive notification,
  ) async {
    try {
      // Check if this device created the bill
      final currentDeviceId = await DeviceIdService.getDeviceId();
      final bill = await _getBill(billId);

      if (bill?.createdDeviceId != currentDeviceId) {
        debugPrint(
          '⏭️ Skipping device notification - bill from different device',
        );
        return;
      }

      // Send via existing NotificationService
      await NotificationService().showImmediateNotification(
        notification.title,
        notification.message,
        billId: notification.billId,
        billTitle: notification.billTitle,
        userId: notification.userId,
      );

      debugPrint('📱 Device notification sent: ${notification.billTitle}');
    } catch (e) {
      debugPrint('⚠️ Error sending device notification: $e');
      // Non-critical error - notification already saved to Hive
    }
  }

  static Future<BillHive?> _getBill(String billId) async {
    try {
      final box = await Hive.openBox<BillHive>('bills');
      return box.get(billId);
    } catch (e) {
      debugPrint('Error getting bill: $e');
      return null;
    }
  }

  /// Generate notification title based on type
  static String _generateTitle(NotificationType type) {
    switch (type) {
      case NotificationType.due:
        return 'Bill Due Today';
      case NotificationType.overdue:
        return 'Bill Overdue';
      case NotificationType.reminder:
        return 'Bill Reminder';
      case NotificationType.paid:
        return 'Bill Paid';
      case NotificationType.recurringCreated:
        return 'New Bill Generated';
    }
  }

  /// Generate notification message
  static String _generateMessage(
    String billTitle,
    NotificationType type,
    double? amount,
    String? vendor,
  ) {
    final amountStr = amount != null ? '\$${amount.toStringAsFixed(2)}' : '';
    final vendorStr = vendor != null ? ' to $vendor' : '';

    switch (type) {
      case NotificationType.due:
        return '$billTitle - $amountStr due today$vendorStr';
      case NotificationType.overdue:
        return '$billTitle - $amountStr is overdue$vendorStr';
      case NotificationType.reminder:
        return '$billTitle - $amountStr reminder$vendorStr';
      case NotificationType.paid:
        return 'Payment of $amountStr recorded for $billTitle';
      case NotificationType.recurringCreated:
        return 'New recurring bill: $billTitle - $amountStr';
    }
  }
}
