import 'package:flutter/foundation.dart';
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

  Future<bool?> _requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidResult = await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosResult = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidResult ?? iosResult;
  }

  // Public method to request permissions with result
  Future<bool?> requestPermissions() async {
    return await _requestPermissions();
  }

  // Check if notifications are enabled at system level
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.areNotificationsEnabled();
      return result ?? false;
    }

    // For iOS, we can't directly check, so assume true
    return true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Schedule notification for a bill with custom settings
  Future<void> scheduleBillNotification(
    BillHive bill, {
    int daysBeforeDue = 1,
    int notificationHour = 9,
    int notificationMinute = 0,
  }) async {
    // Cancel existing notification
    await cancelBillNotification(bill.id);

    // Don't schedule if already paid or deleted
    if (bill.isPaid || bill.isDeleted) return;

    // Calculate notification date based on days before due
    final notificationDate = bill.dueAt.subtract(Duration(days: daysBeforeDue));
    final scheduledTime = tz.TZDateTime(
      tz.local,
      notificationDate.year,
      notificationDate.month,
      notificationDate.day,
      notificationHour,
      notificationMinute,
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

    // Determine notification title based on days before
    String title;
    if (daysBeforeDue == 0) {
      title = 'Bill Due Today';
    } else if (daysBeforeDue == 1) {
      title = 'Bill Due Tomorrow';
    } else if (daysBeforeDue == 7) {
      title = 'Bill Due in 1 Week';
    } else {
      title = 'Bill Due in $daysBeforeDue Days';
    }

    await _notifications.zonedSchedule(
      bill.id.hashCode,
      title,
      '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: bill.id,
    );
  }

  // Cancel notification for a bill
  Future<void> cancelBillNotification(String billId) async {
    await _notifications.cancel(billId.hashCode);
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
