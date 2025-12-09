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
  /// [userId] - User ID who owns this notification
  /// [billId] - Actual bill ID for tracking
  /// [isRecurring] - Whether this is a recurring bill
  /// [recurringType] - Type of recurrence (weekly, monthly, etc.)
  /// [billTitle] - Original bill title for recurring
  /// [billAmount] - Bill amount for recurring
  /// [billVendor] - Bill vendor for recurring
  /// [currentSequence] - Current sequence number for recurring
  /// [repeatCount] - Total repeat count limit (-1 for unlimited)
  static Future<bool> scheduleAlarm({
    required DateTime dateTime,
    required String title,
    required String body,
    required int notificationId,
    String? userId,
    String? billId,
    bool isRecurring = false,
    String? recurringType,
    String? billTitle,
    double? billAmount,
    String? billVendor,
    int currentSequence = 1,
    int repeatCount = -1,
  }) async {
    try {
      debugPrint('📱 Scheduling native alarm:');
      debugPrint('   Time: $dateTime');
      debugPrint('   Title: $title');
      debugPrint('   ID: $notificationId');
      debugPrint('   User ID: $userId');
      debugPrint('   Bill ID: $billId');
      debugPrint('   Is Recurring: $isRecurring');
      debugPrint('   Recurring Type: $recurringType');

      final timeInMillis = dateTime.millisecondsSinceEpoch;

      final result = await platform.invokeMethod('scheduleAlarm', {
        'time': timeInMillis,
        'title': title,
        'body': body,
        'notificationId': notificationId,
        'userId': userId ?? '',
        'billId': billId ?? '',
        'isRecurring': isRecurring,
        'recurringType': recurringType ?? '',
        'billTitle': billTitle ?? '',
        'billAmount': billAmount ?? 0.0,
        'billVendor': billVendor ?? '',
        'currentSequence': currentSequence,
        'repeatCount': repeatCount,
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
