import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'notification_history_service.dart';

/// Service to process pending notifications that were triggered while app was closed
class PendingNotificationService {
  // Platform channel to read from native SharedPreferences
  static const platform = MethodChannel('com.example.bill_manager/prefs');

  /// Check for and process any pending notifications from native SharedPreferences
  static Future<void> processPendingNotifications() async {
    try {
      // Read from native SharedPreferences (notification_history)
      // The native AlarmReceiver saves to this location
      String? pendingData;

      try {
        pendingData = await platform.invokeMethod<String>(
          'getPendingNotifications',
        );
      } catch (e) {
        debugPrint('⚠️ Platform channel not available, trying fallback: $e');
        // Fallback: try reading directly (may not work for native prefs)
        return;
      }

      if (pendingData == null || pendingData == '[]' || pendingData.isEmpty) {
        debugPrint('📭 No pending notifications to process');
        return;
      }

      debugPrint('📬 Processing pending notifications from native layer...');
      debugPrint('📋 Raw data: $pendingData');

      // Parse the JSON array
      final List<dynamic> notifications = jsonDecode(pendingData);

      for (var notification in notifications) {
        final title = notification['title'] as String;
        final body = notification['body'] as String;
        final billId = notification['billId'] as String?;
        final userId = notification['userId'] as String?;
        final timestamp = notification['timestamp'] as int?;

        // Use the actual trigger time from native code
        final sentAt = timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();

        // Check for duplicates - same billId on same day OR same title+body within 5 minutes
        final existingNotifications =
            NotificationHistoryService.getAllNotifications(userId: userId);
        final alreadyExists = existingNotifications.any((n) {
          // Check 1: Same billId on same day
          if (billId != null && billId.isNotEmpty && n.billId == billId) {
            final sameDay =
                n.sentAt.year == sentAt.year &&
                n.sentAt.month == sentAt.month &&
                n.sentAt.day == sentAt.day;
            if (sameDay) return true;
          }
          // Check 2: Same title and body within 5 minutes
          final sameTitle = n.title == title;
          final sameBody = n.body == body;
          final withinTimeWindow =
              n.sentAt.difference(sentAt).inMinutes.abs() < 5;
          return sameTitle && sameBody && withinTimeWindow;
        });

        if (alreadyExists) {
          debugPrint('⏭️ Skipping duplicate notification: $title - $billId');
          continue;
        }

        // Add to notification history with userId and actual timestamp
        await NotificationHistoryService.addNotificationWithTime(
          title: title,
          body: body,
          billId: billId?.isNotEmpty == true ? billId : null,
          billTitle: null,
          userId: userId,
          sentAt: sentAt,
        );

        debugPrint(
          '✅ Added notification to history: $title (userId: $userId, time: $sentAt)',
        );
      }

      // Clear the pending notifications in native SharedPreferences
      try {
        await platform.invokeMethod('clearPendingNotifications');
      } catch (e) {
        debugPrint('⚠️ Failed to clear pending notifications: $e');
      }

      debugPrint('✅ Processed ${notifications.length} pending notification(s)');
    } catch (e) {
      debugPrint('❌ Error processing pending notifications: $e');
    }
  }
}
