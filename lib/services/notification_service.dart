import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/bill_hive.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialize notifications
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // You can navigate to bill details here
    print('Notification tapped: ${response.payload}');
  }

  // Schedule notification for a bill
  Future<void> scheduleBillNotification(BillHive bill) async {
    // Cancel existing notification
    await cancelBillNotification(bill.id);

    // Don't schedule if already paid or deleted
    if (bill.isPaid || bill.isDeleted) return;

    // Schedule notification 1 day before due date at 9 AM
    final notificationTime = bill.dueAt.subtract(const Duration(days: 1));
    final scheduledTime = tz.TZDateTime(
      tz.local,
      notificationTime.year,
      notificationTime.month,
      notificationTime.day,
      9, // 9 AM
      0,
    );

    // Only schedule if in the future
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      bill.id.hashCode, // Use bill ID hash as notification ID
      'Bill Due Tomorrow',
      '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: bill.id,
    );

    // Also schedule on due date at 9 AM
    final dueDateNotificationTime = tz.TZDateTime(
      tz.local,
      bill.dueAt.year,
      bill.dueAt.month,
      bill.dueAt.day,
      9,
      0,
    );

    if (dueDateNotificationTime.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notifications.zonedSchedule(
        (bill.id.hashCode + 1), // Different ID for due date notification
        'Bill Due Today',
        '${bill.title} - \$${bill.amount.toStringAsFixed(2)} is due today!',
        dueDateNotificationTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: bill.id,
      );
    }
  }

  // Cancel notification for a bill
  Future<void> cancelBillNotification(String billId) async {
    await _notifications.cancel(billId.hashCode);
    await _notifications.cancel(billId.hashCode + 1); // Due date notification
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Show immediate notification (for testing or instant alerts)
  Future<void> showImmediateNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
