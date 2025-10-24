import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/bill_hive.dart';
import 'notification_history_service.dart';
import 'alarm_notification_service.dart';

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

    // Set local timezone - detect based on offset
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      final offsetMinutes = offset.inMinutes % 60;

      debugPrint('Device timezone offset: ${offsetHours}h ${offsetMinutes}m');

      // Map common offsets to timezone names
      String locationName = 'UTC';

      if (offsetHours == 5 && offsetMinutes == 30) {
        locationName = 'Asia/Kolkata'; // India
      } else if (offsetHours == 8 && offsetMinutes == 0) {
        locationName = 'Asia/Shanghai'; // China/Singapore
      } else if (offsetHours == -5 && offsetMinutes == 0) {
        locationName = 'America/New_York'; // EST
      } else if (offsetHours == -8 && offsetMinutes == 0) {
        locationName = 'America/Los_Angeles'; // PST
      } else if (offsetHours == 0 && offsetMinutes == 0) {
        locationName = 'UTC';
      } else {
        // For other timezones, try to find a matching one
        locationName = 'UTC';
        debugPrint('⚠️ Unknown timezone offset, using UTC');
      }

      final location = tz.getLocation(locationName);
      tz.setLocalLocation(location);
      debugPrint('✅ Timezone set to: $locationName');
    } catch (e) {
      debugPrint('❌ Error setting timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'bill_reminders',
      'Bill Reminders',
      description: 'Notifications for upcoming bill payments',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Create the channel on Android
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      debugPrint('✅ Notification channel created: bill_reminders');
    }

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

    debugPrint('✅ Notification service initialized');
  }

  Future<bool?> _requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Request notification permission
      final notificationResult = await androidPlugin
          .requestNotificationsPermission();

      // Request exact alarm permission (required for Android 12+)
      final exactAlarmResult = await androidPlugin
          .requestExactAlarmsPermission();

      debugPrint('Notification permission: $notificationResult');
      debugPrint('Exact alarm permission: $exactAlarmResult');

      return notificationResult;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosResult = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return iosResult;
  }

  // Public method to request permissions with result
  Future<bool?> requestPermissions() async {
    return await _requestPermissions();
  }

  // Check if exact alarms are permitted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.canScheduleExactNotifications();
      return result ?? false;
    }

    // For iOS, exact alarms are always allowed
    return true;
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

    // Use alarm manager for reliable background notifications
    await AlarmNotificationService().scheduleBillNotification(
      bill,
      daysBeforeDue: daysBeforeDue,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
    );

    // Calculate notification date based on days before due
    final notificationDate = bill.dueAt.subtract(Duration(days: daysBeforeDue));
    var scheduledTime = tz.TZDateTime(
      tz.local,
      notificationDate.year,
      notificationDate.month,
      notificationDate.day,
      notificationHour,
      notificationMinute,
    );

    // Only schedule if in the future
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledTime.isBefore(now)) {
      debugPrint(
        '⚠️ Notification time ${scheduledTime.toString()} is in the past for bill: ${bill.title}. '
        'Due date: ${bill.dueAt}, Days before: $daysBeforeDue, Time: $notificationHour:$notificationMinute',
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showWhen: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
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

    try {
      await _notifications.zonedSchedule(
        bill.id.hashCode,
        title,
        '${bill.title} - \${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: bill.id,
      );

      debugPrint(
        '✅ Notification scheduled successfully!\n'
        'Notification ID: ${bill.id.hashCode}\n'
        'Bill: ${bill.title}\n'
        'Due date: ${bill.dueAt}\n'
        'Notification time: ${scheduledTime.toString()}\n'
        'Days before: $daysBeforeDue\n'
        'Time: $notificationHour:$notificationMinute\n'
        'Title: $title',
      );
    } catch (e) {
      debugPrint('❌ ERROR scheduling notification: $e');
      rethrow;
    }
  }

  // Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Cancel notification for a bill
  Future<void> cancelBillNotification(String billId) async {
    await _notifications.cancel(billId.hashCode);
    await AlarmNotificationService().cancelBillNotification(billId);
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
    String? billId,
    String? billTitle,
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

    // Save to notification history
    await NotificationHistoryService.addNotification(
      title: title,
      body: body,
      billId: billId,
      billTitle: billTitle,
    );
  }
}
