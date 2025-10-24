import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../models/notification_history.dart';

// Top-level callback function for alarm manager
@pragma('vm:entry-point')
void alarmCallback() async {
  final startTime = DateTime.now();
  debugPrint('🔔🔔🔔 ALARM CALLBACK TRIGGERED at $startTime 🔔🔔🔔');

  try {
    // Initialize Hive for background isolate
    debugPrint('📦 Initializing Hive...');
    await Hive.initFlutter();

    // Register adapters
    debugPrint('📝 Registering adapters...');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BillHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(NotificationHistoryAdapter());
    }

    // Open boxes
    debugPrint('📂 Opening bills box...');
    final billsBox = await Hive.openBox<BillHive>('bills');
    debugPrint('✅ Bills box opened, found ${billsBox.length} bills');

    debugPrint('📂 Opening notification history box...');
    final historyBox = await Hive.openBox<NotificationHistory>(
      'notificationHistory',
    );
    debugPrint('✅ History box opened');

    // Initialize notifications
    debugPrint('🔔 Initializing notification plugin...');
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);
    debugPrint('✅ Notification plugin initialized');

    // Get current time
    final now = DateTime.now();
    debugPrint('⏰ Current time: $now');

    int notificationsSent = 0;

    // Check all bills for notifications
    debugPrint('🔍 Checking bills for notifications...');
    for (var bill in billsBox.values) {
      debugPrint(
        '  📋 Checking bill: ${bill.title} (Paid: ${bill.isPaid}, Deleted: ${bill.isDeleted})',
      );

      if (bill.isPaid || bill.isDeleted) {
        debugPrint('    ⏭️ Skipping (paid or deleted)');
        continue;
      }

      // Check if notification should be sent
      final daysUntilDue = bill.dueAt.difference(now).inDays;
      debugPrint('    📅 Days until due: $daysUntilDue (Due: ${bill.dueAt})');

      // Send notification if due today, tomorrow, or in 7 days
      if (daysUntilDue == 0 || daysUntilDue == 1 || daysUntilDue == 7) {
        String title;
        if (daysUntilDue == 0) {
          title = 'Bill Due Today';
        } else if (daysUntilDue == 1) {
          title = 'Bill Due Tomorrow';
        } else {
          title = 'Bill Due in 1 Week';
        }

        final body =
            '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}';

        debugPrint('    🔔 SENDING NOTIFICATION:');
        debugPrint('       Title: $title');
        debugPrint('       Body: $body');

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
          visibility: NotificationVisibility.public,
        );

        const details = NotificationDetails(android: androidDetails);

        await notifications.show(
          bill.id.hashCode,
          title,
          body,
          details,
          payload: bill.id,
        );

        debugPrint('    ✅ Notification displayed!');

        // Save to notification history
        try {
          final historyEntry = NotificationHistory(
            id: const Uuid().v4(),
            title: title,
            body: body,
            sentAt: DateTime.now(),
            billId: bill.id,
            billTitle: bill.title,
            isRead: false,
            createdAt: DateTime.now(),
          );
          await historyBox.put(historyEntry.id, historyEntry);
          debugPrint(
            '    💾 Saved to notification history (ID: ${historyEntry.id})',
          );
        } catch (e) {
          debugPrint('    ❌ Error saving to history: $e');
        }

        notificationsSent++;
      } else {
        debugPrint('    ⏭️ Not time for notification yet');
      }
    }

    await billsBox.close();
    await historyBox.close();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    debugPrint('🎉 ALARM CALLBACK COMPLETED! 🎉');
    debugPrint('   📊 Total notifications sent: $notificationsSent');
    debugPrint('   ⏱️ Execution time: ${duration.inMilliseconds}ms');
    debugPrint('   🕐 Finished at: $endTime');
  } catch (e, stackTrace) {
    debugPrint('❌❌❌ ERROR IN ALARM CALLBACK: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

// Callback for testing immediate notifications
@pragma('vm:entry-point')
void testAlarmCallback() async {
  final startTime = DateTime.now();
  debugPrint('🧪🧪🧪 TEST ALARM CALLBACK TRIGGERED at $startTime 🧪🧪🧪');

  try {
    // Initialize Hive
    debugPrint('📦 Initializing Hive for test...');
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(NotificationHistoryAdapter());
    }

    debugPrint('📂 Opening notification history box...');
    final historyBox = await Hive.openBox<NotificationHistory>(
      'notificationHistory',
    );
    debugPrint('✅ History box opened');

    // Initialize notifications
    debugPrint('🔔 Initializing notification plugin...');
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);
    debugPrint('✅ Notification plugin initialized');

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
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    final title = 'Test Notification';
    final body =
        'This is a test notification from alarm manager! Time: ${DateTime.now().toString()}';

    debugPrint('🔔 SENDING TEST NOTIFICATION:');
    debugPrint('   Title: $title');
    debugPrint('   Body: $body');

    await notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );

    debugPrint('✅ Test notification displayed!');

    // Save to notification history
    try {
      final historyEntry = NotificationHistory(
        id: const Uuid().v4(),
        title: title,
        body: body,
        sentAt: DateTime.now(),
        billId: null,
        billTitle: 'Test',
        isRead: false,
        createdAt: DateTime.now(),
      );
      await historyBox.put(historyEntry.id, historyEntry);
      debugPrint(
        '💾 Saved test notification to history (ID: ${historyEntry.id})',
      );
    } catch (e) {
      debugPrint('❌ Error saving test notification to history: $e');
    }

    await historyBox.close();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    debugPrint('🎉 TEST ALARM CALLBACK COMPLETED! 🎉');
    debugPrint('   ⏱️ Execution time: ${duration.inMilliseconds}ms');
    debugPrint('   🕐 Finished at: $endTime');
  } catch (e, stackTrace) {
    debugPrint('❌❌❌ ERROR IN TEST ALARM CALLBACK: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

class AlarmNotificationService {
  static final AlarmNotificationService _instance =
      AlarmNotificationService._internal();
  factory AlarmNotificationService() => _instance;
  AlarmNotificationService._internal();

  bool _initialized = false;

  // Initialize alarm manager
  Future<void> init() async {
    if (_initialized) return;

    try {
      await AndroidAlarmManager.initialize();
      _initialized = true;
      debugPrint('✅ Alarm manager initialized');

      // Schedule daily check at 9 AM
      await scheduleDailyCheck();
    } catch (e) {
      debugPrint('❌ Error initializing alarm manager: $e');
    }
  }

  // Schedule daily check for bills at 9 AM
  Future<void> scheduleDailyCheck() async {
    try {
      // Cancel existing alarm
      await AndroidAlarmManager.cancel(0);

      // Schedule daily alarm at 9 AM
      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, 9, 0);

      // If 9 AM has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        0,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      debugPrint('✅ Daily check scheduled for: $scheduledTime');
    } catch (e) {
      debugPrint('❌ Error scheduling daily check: $e');
    }
  }

  // Schedule notification for a specific bill
  Future<void> scheduleBillNotification(
    BillHive bill, {
    int daysBeforeDue = 1,
    int notificationHour = 9,
    int notificationMinute = 0,
  }) async {
    try {
      // Don't schedule if already paid or deleted
      if (bill.isPaid || bill.isDeleted) return;

      // Calculate notification time
      final notificationDate = bill.dueAt.subtract(
        Duration(days: daysBeforeDue),
      );
      final scheduledTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationHour,
        notificationMinute,
      );

      // Only schedule if in the future
      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        debugPrint(
          '⚠️ Notification time $scheduledTime is in the past for bill: ${bill.title}',
        );
        return;
      }

      // Use bill ID hash as alarm ID
      final alarmId = bill.id.hashCode;

      // Cancel existing alarm for this bill
      await AndroidAlarmManager.cancel(alarmId);

      // Schedule new alarm
      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        alarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      debugPrint(
        '✅ Alarm scheduled for bill: ${bill.title}\n'
        'Alarm ID: $alarmId\n'
        'Scheduled time: $scheduledTime\n'
        'Days before due: $daysBeforeDue',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling alarm for bill ${bill.title}: $e');
    }
  }

  // Schedule test notification (10 seconds from now)
  Future<void> scheduleTestNotification() async {
    try {
      final scheduledTime = DateTime.now().add(const Duration(seconds: 10));

      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        999999, // Test alarm ID
        testAlarmCallback,
        exact: true,
        wakeup: true,
      );

      debugPrint('✅ Test alarm scheduled for: $scheduledTime');
    } catch (e) {
      debugPrint('❌ Error scheduling test alarm: $e');
    }
  }

  // Cancel notification for a bill
  Future<void> cancelBillNotification(String billId) async {
    try {
      final alarmId = billId.hashCode;
      await AndroidAlarmManager.cancel(alarmId);
      debugPrint('✅ Alarm cancelled for bill ID: $billId (alarm ID: $alarmId)');
    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  // Cancel all alarms (except daily check)
  Future<void> cancelAllNotifications() async {
    try {
      // Note: android_alarm_manager_plus doesn't have a cancel all method
      // We need to track alarm IDs and cancel them individually
      // For now, we'll just cancel the daily check
      await AndroidAlarmManager.cancel(0);
      debugPrint('✅ Daily check alarm cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling alarms: $e');
    }
  }
}
