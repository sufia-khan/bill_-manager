import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_history_service.dart';

/// Service to process pending notifications that were triggered while app was closed
class PendingNotificationService {
  /// Check for and process any pending notifications from SharedPreferences
  static Future<void> processPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_notifications');

      if (pendingData == null || pendingData == '[]') {
        debugPrint('📭 No pending notifications to process');
        return;
      }

      debugPrint('📬 Processing pending notifications from native layer...');

      // Parse the JSON array
      final List<dynamic> notifications = jsonDecode(pendingData);

      for (var notification in notifications) {
        final title = notification['title'] as String;
        final body = notification['body'] as String;
        final billId = notification['billId'] as String?;

        // Add to notification history
        await NotificationHistoryService.addNotification(
          title: title,
          body: body,
          billId: billId?.isNotEmpty == true ? billId : null,
          billTitle: null,
        );

        debugPrint('✅ Added notification to history: $title');
      }

      // Clear the pending notifications
      await prefs.setString('pending_notifications', '[]');
      debugPrint('✅ Processed ${notifications.length} pending notification(s)');
    } catch (e) {
      debugPrint('❌ Error processing pending notifications: $e');
    }
  }
}
