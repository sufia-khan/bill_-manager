import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native AlarmManager service using platform channels
/// This bypasses plugin issues and uses Android's AlarmManager directly
class NativeAlarmService {
  static const platform = MethodChannel('com.example.bill_manager/alarm');

  /// Schedule an alarm notification
  ///
  /// [dateTime] - When to show the notification
  /// [title] - Notification title
  /// [body] - Notification body
  /// [notificationId] - Unique ID for this notification
  static Future<bool> scheduleAlarm({
    required DateTime dateTime,
    required String title,
    required String body,
    required int notificationId,
  }) async {
    try {
      debugPrint('📱 Scheduling native alarm:');
      debugPrint('   Time: $dateTime');
      debugPrint('   Title: $title');
      debugPrint('   ID: $notificationId');

      final timeInMillis = dateTime.millisecondsSinceEpoch;

      final result = await platform.invokeMethod('scheduleAlarm', {
        'time': timeInMillis,
        'title': title,
        'body': body,
        'notificationId': notificationId,
      });

      debugPrint('✅ Native alarm scheduled successfully!');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to schedule native alarm: ${e.message}');
      return false;
    }
  }

  /// Cancel a scheduled alarm
  static Future<bool> cancelAlarm(int notificationId) async {
    try {
      final result = await platform.invokeMethod('cancelAlarm', {
        'notificationId': notificationId,
      });
      debugPrint('✅ Native alarm cancelled: $notificationId');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to cancel native alarm: ${e.message}');
      return false;
    }
  }
}
