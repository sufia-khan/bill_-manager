import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Add a notification to history (Hive + Firestore)
  // Automatically checks for duplicates before adding
  static Future<bool> addNotification({
    required String title,
    required String body,
    String? billId,
    String? billTitle,
    String? userId, // Add userId parameter
  }) async {
    try {
      await init();
      if (_box == null) return false;

      final now = DateTime.now();

      // Check for duplicates - same billId within same day OR same title+body within 5 minutes
      final existingNotifications = getAllNotifications(userId: userId);
      final alreadyExists = existingNotifications.any((n) {
        // Check 1: Same billId on same day (prevents duplicate for same bill)
        if (billId != null && billId.isNotEmpty && n.billId == billId) {
          final sameDay =
              n.sentAt.year == now.year &&
              n.sentAt.month == now.month &&
              n.sentAt.day == now.day;
          if (sameDay) return true;
        }

        // Check 2: Same title and body within 5 minutes (catches exact duplicates)
        final sameTitle = n.title == title;
        final sameBody = n.body == body;
        final withinTimeWindow = n.sentAt.difference(now).inMinutes.abs() < 5;
        return sameTitle && sameBody && withinTimeWindow;
      });

      if (alreadyExists) {
        print('⏭️ Duplicate notification skipped: $title - $body');
        return false;
      }

      final notification = NotificationHistory(
        id: const Uuid().v4(),
        title: title,
        body: body,
        sentAt: now,
        billId: billId,
        billTitle: billTitle,
        isRead: false,
        createdAt: now,
        userId: userId, // Store userId
      );

      // Save to Hive
      await _box!.put(notification.id, notification);

      // Save to Firestore if userId is present
      if (userId != null) {
        await _addNotificationToFirestore(userId, notification);
      }

      return true;
    } catch (e) {
      print('Error adding notification to history: $e');
      return false;
    }
  }

  // Add a notification to history with specific timestamp (Hive + Firestore)
  // Used for notifications that were triggered while app was closed
  // Automatically checks for duplicates before adding
  static Future<bool> addNotificationWithTime({
    required String title,
    required String body,
    required DateTime sentAt,
    String? billId,
    String? billTitle,
    String? userId,
  }) async {
    try {
      await init();
      if (_box == null) return false;

      // Check for duplicates - same billId on same day OR same title+body within 5 minutes
      final existingNotifications = getAllNotifications(userId: userId);
      final alreadyExists = existingNotifications.any((n) {
        // Check 1: Same billId on same day (prevents duplicate for same bill)
        if (billId != null && billId.isNotEmpty && n.billId == billId) {
          final sameDay =
              n.sentAt.year == sentAt.year &&
              n.sentAt.month == sentAt.month &&
              n.sentAt.day == sentAt.day;
          if (sameDay) return true;
        }

        // Check 2: Same title and body within 5 minutes (catches exact duplicates)
        final sameTitle = n.title == title;
        final sameBody = n.body == body;
        final withinTimeWindow =
            n.sentAt.difference(sentAt).inMinutes.abs() < 5;
        return sameTitle && sameBody && withinTimeWindow;
      });

      if (alreadyExists) {
        print('⏭️ Duplicate notification skipped: $title - $billId at $sentAt');
        return false;
      }

      final notification = NotificationHistory(
        id: const Uuid().v4(),
        title: title,
        body: body,
        sentAt: sentAt, // Use the actual trigger time
        billId: billId,
        billTitle: billTitle,
        isRead: false,
        createdAt: DateTime.now(),
        userId: userId,
      );

      // Save to Hive
      await _box!.put(notification.id, notification);

      // Save to Firestore if userId is present
      if (userId != null) {
        await _addNotificationToFirestore(userId, notification);
      }

      print('📝 Added notification with timestamp: $title at $sentAt');
      return true;
    } catch (e) {
      print('Error adding notification with time: $e');
      return false;
    }
  }

  // Firestore: Add notification to 'users/{userId}/notifications'
  static Future<void> _addNotificationToFirestore(
    String userId,
    NotificationHistory notification,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id);

      await docRef.set({
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
        'billId': notification.billId,
        'billTitle': notification.billTitle,
        'timestamp': Timestamp.fromDate(
          notification.sentAt,
        ), // Use Firestore Timestamp
        'status': notification.isRead ? 'read' : 'unread',
        // Also save isRead for compatibility
        'isRead': notification.isRead,
      });

      print('☁️ Saved notification to Firestore: ${notification.title}');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  // Firestore: Get notifications stream for a user
  // Used by NotificationScreen
  static Stream<QuerySnapshot> getFirestoreNotificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Firestore: Mark notification as read
  static Future<void> markAsReadInFirestore(
    String userId,
    String notificationId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'status': 'read', 'isRead': true});
    } catch (e) {
      print('❌ Error marking Firestore notification as read: $e');
    }
  }

  // Firestore: Mark ALL notifications as read
  static Future<void> markAllAsReadInFirestore(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      final snapshot = await collection
          .where('status', isEqualTo: 'unread')
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'read', 'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      final error = e.toString();
      if (error.contains('permission-denied') ||
          error.contains('PERMISSION_DENIED')) {
        print(
          '⚠️ Permission denied marking notifications read. Check Firestore rules or auth state.',
        );
      } else {
        print('❌ Error marking all Firestore notifications as read: $e');
      }
    }
  }

  // Firestore: Delete notification
  static Future<void> deleteNotificationFromFirestore(
    String userId,
    String notificationId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('❌ Error deleting Firestore notification: $e');
    }
  }

  // Firestore: Clear all notifications
  static Future<void> clearAllNotificationsFromFirestore(String userId) async {
    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await collection.get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('❌ Error clearing all Firestore notifications: $e');
    }
  }

  // Get all notifications for current user (sorted by sentAt descending)
  static List<NotificationHistory> getAllNotifications({String? userId}) {
    try {
      if (_box == null || !_box!.isOpen) return [];

      final notifications = _box!.values.toList();

      // Filter by userId if provided
      final filteredNotifications = userId != null
          ? notifications.where((n) => n.userId == userId).toList()
          : notifications;

      filteredNotifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return filteredNotifications;
    } catch (e) {
      print('Error getting all notifications: $e');
      return [];
    }
  }

  // Get paginated notifications for current user
  static List<NotificationHistory> getNotifications({
    int offset = 0,
    int limit = 10,
    String? userId, // Add userId parameter
  }) {
    try {
      final allNotifications = getAllNotifications(userId: userId);
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

  // Get total count for current user
  static int getTotalCount({String? userId}) {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      if (userId == null) return _box!.length;
      return _box!.values.where((n) => n.userId == userId).length;
    } catch (e) {
      print('Error getting notification count: $e');
      return 0;
    }
  }

  // Get unread count for current user
  static int getUnreadCount({String? userId}) {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      if (userId == null) {
        return _box!.values.where((n) => !n.isRead).length;
      }
      return _box!.values.where((n) => n.userId == userId && !n.isRead).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String id, {String? userId}) async {
    try {
      await init();
      if (_box == null) return;

      final notification = _box!.get(id);
      if (notification != null) {
        final updated = notification.copyWith(isRead: true);
        await _box!.put(id, updated);
      }

      // Sync with Firestore if userId provided
      if (userId != null) {
        await markAsReadInFirestore(userId, id);
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Highlight a notification temporarily (for tap navigation)
  static Future<void> highlightNotification(String notificationId) async {
    try {
      await init();
      if (_box == null) return;

      final notification = _box!.get(notificationId);
      if (notification != null) {
        final updated = notification.copyWith(isHighlighted: true);
        await _box!.put(notificationId, updated);
      }
    } catch (e) {
      print('Error highlighting notification: $e');
    }
  }

  // Clear highlight from notification
  static Future<void> clearHighlight(String notificationId) async {
    try {
      await init();
      if (_box == null) return;

      final notification = _box!.get(notificationId);
      if (notification != null) {
        final updated = notification.copyWith(isHighlighted: false);
        await _box!.put(notificationId, updated);
      }
    } catch (e) {
      print('Error clearing highlight: $e');
    }
  }

  // Find notification by billId (for tap navigation)
  static NotificationHistory? findByBillId(String billId, {String? userId}) {
    try {
      if (_box == null || !_box!.isOpen) return null;

      final notifications = getAllNotifications(userId: userId);
      // Return the most recent notification for this bill
      for (final n in notifications) {
        if (n.billId == billId) {
          return n;
        }
      }
      return null;
    } catch (e) {
      print('Error finding notification by billId: $e');
      return null;
    }
  }

  // Mark all as read
  static Future<void> markAllAsRead({String? userId}) async {
    try {
      await init();
      if (_box == null) return;

      final notifications = _box!.values.toList();
      for (final notification in notifications) {
        if (userId != null && notification.userId != userId) continue;

        if (!notification.isRead) {
          final updated = notification.copyWith(isRead: true);
          await _box!.put(notification.id, updated);
        }
      }

      // Sync with Firestore
      if (userId != null) {
        await markAllAsReadInFirestore(userId);
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Remove duplicate notifications from history
  // Keeps the oldest notification and removes newer duplicates
  static Future<int> removeDuplicates() async {
    try {
      await init();
      if (_box == null) return 0;

      final notifications = _box!.values.toList();
      // Sort by sentAt ascending (oldest first)
      notifications.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      final seenByBillAndDay = <String, NotificationHistory>{};
      final seenByContent = <String, NotificationHistory>{};
      final toDelete = <String>[];

      for (final notification in notifications) {
        bool isDuplicate = false;

        // Check 1: Same billId on same day
        if (notification.billId != null && notification.billId!.isNotEmpty) {
          final dayKey =
              '${notification.billId}_${notification.sentAt.year}_${notification.sentAt.month}_${notification.sentAt.day}_${notification.userId}';
          if (seenByBillAndDay.containsKey(dayKey)) {
            isDuplicate = true;
          } else {
            seenByBillAndDay[dayKey] = notification;
          }
        }

        // Check 2: Same title+body within 5 minute window
        if (!isDuplicate) {
          final timeKey =
              notification.sentAt.millisecondsSinceEpoch ~/
              300000; // 5 min buckets
          final contentKey =
              '${notification.title}_${notification.body}_${notification.userId}_$timeKey';
          if (seenByContent.containsKey(contentKey)) {
            isDuplicate = true;
          } else {
            seenByContent[contentKey] = notification;
          }
        }

        if (isDuplicate) {
          print(
            '🔍 Found duplicate: ${notification.title} - ${notification.body}',
          );
          toDelete.add(notification.id);
        }
      }

      // Delete duplicates
      for (final id in toDelete) {
        await _box!.delete(id);
      }

      if (toDelete.isNotEmpty) {
        print('🧹 Removed ${toDelete.length} duplicate notifications');
      }

      return toDelete.length;
    } catch (e) {
      print('Error removing duplicates: $e');
      return 0;
    }
  }

  // Delete a notification
  static Future<void> deleteNotification(String id, {String? userId}) async {
    try {
      await init();
      if (_box == null) return;
      await _box!.delete(id);

      // Sync with Firestore
      if (userId != null) {
        await deleteNotificationFromFirestore(userId, id);
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete multiple notifications
  static Future<void> deleteNotifications(
    List<String> ids, {
    String? userId,
  }) async {
    try {
      await init();
      if (_box == null) return;

      // Delete from Hive
      await _box!.deleteAll(ids);

      // Sync with Firestore
      if (userId != null) {
        // Firestore batch delete
        final batch = FirebaseFirestore.instance.batch();
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications');

        for (final id in ids) {
          batch.delete(collection.doc(id));
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error deleting multiple notifications: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAll({String? userId}) async {
    try {
      await init();
      if (_box == null) return;
      await _box!
          .clear(); // This clears hive for everyone - maybe redundant if filtered
      // If we only want to clear for current user in Hive, we would iterate and delete.
      // But clearing Hive usually means "Clear local history".
      // Let's stick to user request: "Clear All" in UI likely means clear specific user's.

      // Sync with Firestore
      if (userId != null) {
        await clearAllNotificationsFromFirestore(userId);
      }
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
          // Optional: also delete from Firestore logic here, though usually Firestore handles retention
        }
      }
    } catch (e) {
      print('Error deleting old notifications: $e');
    }
  }

  // Add a scheduled notification that will be tracked
  // This is called when a notification is scheduled, not when it's sent
  static Future<void> trackScheduledNotification({
    required String billId,
    required String billTitle,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? userId, // Add userId parameter
  }) async {
    try {
      // Store in a separate box for tracking
      final trackingBox = await Hive.openBox('scheduledNotifications');

      // Store with billId as primary key for easy lookup
      // This allows checking if a notification is already scheduled
      final primaryKey = 'scheduled_$billId';
      await trackingBox.put(primaryKey, {
        'billId': billId,
        'billTitle': billTitle,
        'title': title,
        'body': body,
        'scheduledFor': scheduledFor
            .millisecondsSinceEpoch, // Store as milliseconds for comparison
        'scheduledForIso': scheduledFor
            .toIso8601String(), // Keep ISO for readability
        'tracked': false,
        'userId': userId, // Store userId
      });

      // Also store with timestamp key for recurring bills history
      final uniqueKey = '${billId}_${scheduledFor.millisecondsSinceEpoch}';
      await trackingBox.put(uniqueKey, {
        'billId': billId,
        'billTitle': billTitle,
        'title': title,
        'body': body,
        'scheduledFor': scheduledFor.toIso8601String(),
        'tracked': false,
        'userId': userId,
      });
    } catch (e) {
      print('Error tracking scheduled notification: $e');
    }
  }

  // Check for triggered notifications and add them to history
  // This processes ALL triggered notifications regardless of user
  // The notification screen will filter by current user when displaying
  static Future<void> checkAndAddTriggeredNotifications({
    String? currentUserId,
  }) async {
    try {
      final trackingBox = await Hive.openBox('scheduledNotifications');
      final now = DateTime.now();

      final keys = trackingBox.keys.toList();
      for (final key in keys) {
        final data = trackingBox.get(key) as Map?;
        if (data == null) continue;

        final scheduledFor = DateTime.parse(data['scheduledFor'] as String);
        final tracked = data['tracked'] as bool? ?? false;
        final userId = data['userId'] as String?;

        // CRITICAL FIX: Only process notifications for the CURRENT user
        // Processing other users' notifications causes Permission Denied errors
        // because we try to write to their Firestore collection with our token.
        if (currentUserId != null && userId != currentUserId) {
          continue;
        }

        // Process ALL notifications whose time has passed (not just current user)
        // This ensures notifications are added to history for when user logs in

        // If the scheduled time has passed and we haven't tracked it yet
        if (scheduledFor.isBefore(now) && !tracked) {
          // Check if this notification already exists in history (avoid duplicates)
          // Check across ALL notifications, not just current user
          final existingNotifications = getAllNotifications(userId: userId);
          final alreadyExists = existingNotifications.any(
            (n) =>
                n.billId == data['billId'] &&
                n.title == data['title'] &&
                n.sentAt.difference(scheduledFor).inMinutes.abs() <
                    5, // Within 5 minutes
          );

          if (!alreadyExists) {
            // Add to notification history with the scheduled time
            // This will now ALSO save to Firestore if userId is present!
            await addNotificationWithTime(
              title: data['title'] as String,
              body: data['body'] as String,
              billId: data['billId'] as String,
              billTitle: data['billTitle'] as String,
              userId: userId, // Keep the original userId
              sentAt: scheduledFor, // Use the scheduled time
            );
            print(
              '✅ Added triggered notification to history: ${data['title']} for user: $userId at $scheduledFor',
            );
          }

          // Mark as tracked
          data['tracked'] = true;
          await trackingBox.put(key, data);
        }
      }

      // Clean up old tracked notifications (older than 7 days)
      final cutoffDate = now.subtract(const Duration(days: 7));
      for (final key in keys) {
        final data = trackingBox.get(key) as Map?;
        if (data == null) continue;

        final scheduledFor = DateTime.parse(data['scheduledFor'] as String);
        final tracked = data['tracked'] as bool? ?? false;

        if (tracked && scheduledFor.isBefore(cutoffDate)) {
          await trackingBox.delete(key);
        }
      }
    } catch (e) {
      print('Error checking triggered notifications: $e');
    }
  }

  // Remove tracking for a cancelled notification
  // Removes all tracking entries for a given billId (including recurring occurrences)
  static Future<void> removeScheduledTracking(String billId) async {
    try {
      final trackingBox = await Hive.openBox('scheduledNotifications');
      // Find and delete all entries that match this billId
      final keysToDelete = trackingBox.keys
          .where(
            (key) =>
                key.toString().startsWith('${billId}_') ||
                key == billId ||
                key == 'scheduled_$billId',
          )
          .toList();
      for (final key in keysToDelete) {
        await trackingBox.delete(key);
      }
    } catch (e) {
      print('Error removing scheduled tracking: $e');
    }
  }

  /// Clear all scheduled notification tracking for a specific user
  /// This is called on logout to ensure notifications aren't triggered for this user
  /// while they're logged out, but preserved notification history for when they log back in
  static Future<void> clearScheduledTrackingForUser(String? userId) async {
    if (userId == null) {
      print('⚠️ No userId provided for clearing scheduled tracking');
      return;
    }

    try {
      final trackingBox = await Hive.openBox('scheduledNotifications');
      final keys = trackingBox.keys.toList();
      int deletedCount = 0;

      for (final key in keys) {
        try {
          final data = trackingBox.get(key);
          if (data != null && data is Map) {
            final trackingUserId = data['userId'] as String?;
            if (trackingUserId == userId) {
              await trackingBox.delete(key);
              deletedCount++;
            }
          }
        } catch (e) {
          print('⚠️ Error processing tracking key $key: $e');
        }
      }

      print(
        '🗑️ Cleared $deletedCount scheduled notification tracking entries for user: $userId',
      );
    } catch (e) {
      print('Error clearing scheduled tracking for user: $e');
    }
  }

  // Check all bills and add notifications for any whose notification time has passed
  // This is called when user logs in to show missed notifications
  static Future<void> checkMissedNotificationsForUser({
    required String userId,
    required List<dynamic> bills, // List of BillHive objects
  }) async {
    try {
      print('\n🔍 Checking missed notifications for user: $userId');
      print('📋 Total bills to check: ${bills.length}');

      await init();
      if (_box == null) {
        print('❌ Notification history box is null');
        return;
      }

      final now = DateTime.now();
      final existingNotifications = getAllNotifications(userId: userId);
      print('📬 Existing notifications: ${existingNotifications.length}');

      int addedCount = 0;

      for (final bill in bills) {
        // Skip if bill is paid, deleted, or archived
        if (bill.isPaid || bill.isDeleted || bill.isArchived) continue;

        print('📌 Checking bill: ${bill.title} (Due: ${bill.dueAt})');

        // Get notification settings for this bill
        final reminderTiming = bill.reminderTiming ?? '1 Day Before';
        final notificationTime = bill.notificationTime ?? '09:00';

        // Calculate when notification should have fired
        int daysOffset;
        switch (reminderTiming) {
          case 'Same Day':
            daysOffset = 0;
            break;
          case '1 Day Before':
            daysOffset = 1;
            break;
          case '2 Days Before':
            daysOffset = 2;
            break;
          case '1 Week Before':
            daysOffset = 7;
            break;
          default:
            daysOffset = 1;
        }

        final notificationDate = bill.dueAt.subtract(
          Duration(days: daysOffset),
        );
        final timeParts = notificationTime.split(':');
        final notificationHour = int.parse(timeParts[0]);
        final notificationMinute = int.parse(timeParts[1]);

        final scheduledTime = DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          notificationHour,
          notificationMinute,
        );

        // Check if notification time has passed
        if (scheduledTime.isBefore(now)) {
          // Check if notification already exists (avoid duplicates)
          final alreadyExists = existingNotifications.any(
            (n) =>
                n.billId == bill.id &&
                n.sentAt.difference(scheduledTime).inMinutes.abs() < 5,
          );

          if (!alreadyExists) {
            // ONLY overdue notifications - no reminder notifications
            String title = 'Bill Overdue';

            final body =
                '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}';

            // Add to notification history with the actual scheduled time
            // Saves to Firestore as well!
            await addNotificationWithTime(
              title: title,
              body: body,
              billId: bill.id,
              billTitle: bill.title,
              userId: userId,
              sentAt: scheduledTime, // Use the scheduled time, not current time
            );

            addedCount++;
            print(
              '✅ Added missed notification for bill: ${bill.title} at $scheduledTime',
            );
          } else {
            print('⏭️ Skipped ${bill.title} (already exists)');
          }
        } else {
          print('⏭️ Skipped ${bill.title} (notification time not yet passed)');
        }
      }

      print(
        '✅ Missed notification check complete: Added $addedCount notifications\n',
      );
    } catch (e, stackTrace) {
      print('❌ Error checking missed notifications: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
