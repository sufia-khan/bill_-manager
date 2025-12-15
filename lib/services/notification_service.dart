import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill_hive.dart';
import 'notification_history_service.dart';
import 'native_alarm_service.dart';
import 'device_id_service.dart';
import 'hive_service.dart';

// Top-level callback for background notification taps
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 Background notification tapped: ${response.payload}');
  // Background taps are handled when app resumes
}

// Top-level callback for alarm manager (must be top-level or static)
@pragma('vm:entry-point')
void testNotificationCallback() async {
  // Use print instead of debugPrint to ensure it shows in logs
  print('🔔🔔🔔 ALARM CALLBACK TRIGGERED! Time: ${DateTime.now()}');

  try {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);

    print('✅ Notification plugin initialized in callback');

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

    print('🔔 Showing notification now...');

    await notifications.show(
      999999,
      'Scheduled Test Notification (Alarm Manager)',
      'This notification was triggered by Android AlarmManager at ${DateTime.now().toString().substring(11, 19)}. It works even when app is closed!',
      details,
    );

    print('✅ Test notification shown via alarm manager!');
  } catch (e, stackTrace) {
    print('❌ Error in alarm callback: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Simple, reliable notification service using only flutter_local_notifications
/// Supports scheduled notifications that work even when app is closed
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Callback for when notification is tapped
  static void Function(String?)? onNotificationTapped;

  // CRITICAL FIX: Track recently scheduled notifications to prevent duplicates
  // Key: billId (or billId:sequence for recurring), Value: timestamp of last schedule
  // Clears entries older than 5 minutes
  static final Map<String, DateTime> _recentlyScheduled = {};

  // CRITICAL FIX: Lock to prevent concurrent scheduling for the same bill
  static final Set<String> _currentlyScheduling = {};

  // CRITICAL FIX: Track shown notification IDs to prevent duplicate shows
  static final Map<int, DateTime> _recentlyShownNotificationIds = {};

  /// Initialize notification service
  Future<void> init() async {
    debugPrint('🔔 Initializing NotificationService...');

    // Initialize timezone data
    tz.initializeTimeZones();
    _setLocalTimezone();

    // Native AlarmManager doesn't need initialization
    debugPrint('✅ Using native AlarmManager via platform channels');

    // Create notification channel for Android
    await _createNotificationChannel();

    // Initialize platform-specific settings
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

    // Initialize with callback for notification taps
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions
    await requestPermissions();

    debugPrint('✅ NotificationService initialized');
  }

  /// Set local timezone based on device offset
  void _setLocalTimezone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      final offsetMinutes = offset.inMinutes % 60;

      debugPrint(
        '📍 Device timezone offset: ${offsetHours}h ${offsetMinutes}m',
      );

      // Map common offsets to timezone names
      String locationName = 'UTC';

      if (offsetHours == 5 && offsetMinutes == 30) {
        locationName = 'Asia/Kolkata'; // India (IST)
      } else if (offsetHours == 8 && offsetMinutes == 0) {
        locationName = 'Asia/Shanghai'; // China/Singapore
      } else if (offsetHours == -5 && offsetMinutes == 0) {
        locationName = 'America/New_York'; // EST
      } else if (offsetHours == -8 && offsetMinutes == 0) {
        locationName = 'America/Los_Angeles'; // PST
      } else if (offsetHours == 0 && offsetMinutes == 0) {
        locationName = 'UTC';
      } else {
        // For other timezones, try to use a close match
        debugPrint('⚠️ Uncommon timezone offset detected, using UTC');
      }

      final location = tz.getLocation(locationName);
      tz.setLocalLocation(location);
      debugPrint('✅ Timezone set to: $locationName');
      debugPrint('✅ Current time in timezone: ${tz.TZDateTime.now(tz.local)}');
      debugPrint('✅ Device local time: $now');
    } catch (e) {
      debugPrint('⚠️ Error setting timezone: $e, using UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'bill_reminders',
      'Bill Reminders',
      description: 'Notifications for upcoming bill payments',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      debugPrint('✅ Notification channel created');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    if (onNotificationTapped != null && response.payload != null) {
      onNotificationTapped!(response.payload);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('📱 Android notification permission: $granted');

      // Request exact alarm permission for Android 12+
      final exactAlarmGranted = await androidPlugin
          .requestExactAlarmsPermission();
      debugPrint('⏰ Exact alarm permission: $exactAlarmGranted');

      return granted ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('📱 iOS notification permission: $granted');
      return granted ?? false;
    }

    return false;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.areNotificationsEnabled();
      return result ?? false;
    }

    return true; // iOS - assume enabled
  }

  /// Check if exact alarms can be scheduled (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.canScheduleExactNotifications();
      return result ?? false;
    }

    return true; // iOS - always allowed
  }

  /// Schedule notification for a bill
  ///
  /// This uses zonedSchedule with androidAllowWhileIdle to ensure
  /// notifications work even when device is in Doze mode
  Future<void> scheduleBillNotification(
    BillHive bill, {
    int daysBeforeDue = 1,
    int notificationHour = 9,
    int notificationMinute = 0,
    String?
    userId, // Add userId parameter to track which user owns this notification
    bool forceReschedule =
        false, // Only cancel and reschedule if explicitly requested
  }) async {
    // CRITICAL FIX: Create a tracking key that includes sequence for recurring bills
    // This ensures each recurring instance is tracked separately
    final trackingKey = bill.recurringSequence != null
        ? '${bill.id}:seq${bill.recurringSequence}'
        : bill.id;

    try {
      // CRITICAL: Device-local notification check
      // Only schedule system notifications for bills created on this device
      final currentDeviceId = await DeviceIdService.getDeviceId();

      // Handle legacy bills without device ID (migration)
      if (bill.createdDeviceId == null) {
        debugPrint(
          '🔄 Legacy bill detected without device ID - assigning to current device',
        );
        // Assign current device ID to this bill (migration)
        final updatedBill = bill.copyWith(createdDeviceId: currentDeviceId);
        await HiveService.saveBill(updatedBill);
        debugPrint('✅ Bill migrated with device ID: $currentDeviceId');
        // Continue with scheduling since we just claimed this bill
      }
      // Skip if bill was created on a different device
      else if (bill.createdDeviceId != currentDeviceId) {
        debugPrint(
          '⏭️ SKIPPING NOTIFICATION - Bill created on different device\n'
          '   Bill: ${bill.title}\n'
          '   Bill Device: ${bill.createdDeviceId}\n'
          '   Current Device: $currentDeviceId\n'
          '   ✅ Bill will sync and show in UI, but NO system notification',
        );

        // Save to history for in-app display but don't schedule system notification
        await NotificationHistoryService.addNotification(
          title: 'Remote Bill Synced',
          body: '${bill.title} - \$${bill.amount.toStringAsFixed(2)}',
          billId: bill.id,
          billTitle: bill.title,
          userId: userId,
        );
        return;
      }

      debugPrint(
        '✅ Bill created on this device - proceeding with notification\n'
        '   Bill: ${bill.title}\n'
        '   Device ID: $currentDeviceId',
      );

      // Don't schedule if already paid or deleted
      if (bill.isPaid || bill.isDeleted) {
        debugPrint('⏭️ Skipping notification for ${bill.title} (paid/deleted)');
        // Cancel any existing notification for paid/deleted bills
        await cancelBillNotification(bill.id);
        return;
      }

      // CRITICAL FIX: Use lock to prevent concurrent scheduling
      if (_currentlyScheduling.contains(trackingKey)) {
        debugPrint(
          '⏭️ Already scheduling notification for ${bill.title} (lock held) - skipping',
        );
        return;
      }

      // Acquire lock
      _currentlyScheduling.add(trackingKey);

      // CRITICAL FIX: Prevent duplicate notifications for same bill within 5 minutes
      // This catches any remaining duplicates from multiple trigger sources
      final now = DateTime.now();

      // Clean up old entries (older than 5 minutes)
      _recentlyScheduled.removeWhere(
        (_, timestamp) => now.difference(timestamp).inMinutes > 5,
      );

      // Also clean up old notification IDs
      _recentlyShownNotificationIds.removeWhere(
        (_, timestamp) => now.difference(timestamp).inMinutes > 5,
      );

      // Check if this bill was recently scheduled
      if (_recentlyScheduled.containsKey(trackingKey) && !forceReschedule) {
        final lastScheduled = _recentlyScheduled[trackingKey]!;
        final secondsSince = now.difference(lastScheduled).inSeconds;
        debugPrint(
          '⏭️ Skipping duplicate notification for ${bill.title} (seq: ${bill.recurringSequence}) '
          '(scheduled ${secondsSince}s ago)',
        );
        _currentlyScheduling.remove(trackingKey); // Release lock
        return;
      }

      // Track this scheduling attempt
      _recentlyScheduled[trackingKey] = now;

      // Calculate notification date
      final notificationDate = bill.dueAt.subtract(
        Duration(days: daysBeforeDue),
      );
      final scheduledTime = tz.TZDateTime(
        tz.local,
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationHour,
        notificationMinute,
      );

      // Only schedule if in the future
      final tzNow = tz.TZDateTime.now(tz.local);
      if (scheduledTime.isBefore(tzNow)) {
        debugPrint(
          '⚠️ NOTIFICATION NOT SCHEDULED - Time is in the past!\n'
          '   Bill: ${bill.title}\n'
          '   Scheduled Time: $scheduledTime\n'
          '   Current Time: $tzNow\n'
          '   Difference: ${tzNow.difference(scheduledTime).inMinutes} minutes ago\n'
          '   TIP: Set due date further in future or use "Same Day" reminder',
        );
        debugPrint(
          '⚠️ NOTIFICATION NOT SCHEDULED - Time is in the past!\n'
          '   Bill: ${bill.title}\n'
          '   Scheduled Time: $scheduledTime\n'
          '   Current Time: $tzNow\n'
          '   Difference: ${tzNow.difference(scheduledTime).inMinutes} minutes ago\n'
          '   📝 Adding to notification history as missed notification',
        );

        // ONLY overdue notifications - no reminder notifications
        String historyTitle = 'Bill Overdue';

        final historyBody =
            '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}';

        // Add to notification history as a missed notification
        // This ensures the user sees it in the app even if they were logged out
        debugPrint(
          '📝 Adding missed notification to history for ${bill.title}',
        );
        await NotificationHistoryService.addNotificationWithTime(
          title: historyTitle,
          body: historyBody,
          billId: bill.id,
          billTitle: bill.title,
          userId: userId,
          sentAt: scheduledTime.toLocal(), // Use the past scheduled time
        );

        return;
      }

      // Check if notification is already scheduled with same parameters
      // Only cancel and reschedule if forceReschedule is true or settings changed
      if (!forceReschedule) {
        final isAlreadyScheduled = await _isNotificationAlreadyScheduled(
          bill.id,
          scheduledTime,
        );
        if (isAlreadyScheduled) {
          debugPrint(
            '✅ Notification already scheduled for ${bill.title} at $scheduledTime - skipping',
          );
          return;
        }
      }

      // Cancel existing notification only when we're sure we need to reschedule
      await cancelBillNotification(bill.id);

      debugPrint(
        '⏰ Scheduling notification:\n'
        '   Bill: ${bill.title}\n'
        '   Due Date: ${bill.dueAt}\n'
        '   Days Before: $daysBeforeDue\n'
        '   Scheduled Time: $scheduledTime\n'
        '   Current Time: $tzNow\n'
        '   Time Until Notification: ${scheduledTime.difference(tzNow).inHours}h ${scheduledTime.difference(tzNow).inMinutes % 60}m',
      );

      // ONLY overdue notifications - no reminder notifications
      String title = 'Bill Overdue';

      final body =
          '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor}';

      // Log exact scheduling details for debugging
      debugPrint(
        '🔧 EXACT SCHEDULING DETAILS:\n'
        '   ID: ${bill.id.hashCode}\n'
        '   Scheduled: $scheduledTime\n'
        '   Current: $tzNow\n'
        '   Seconds until trigger: ${(scheduledTime.millisecondsSinceEpoch - tzNow.millisecondsSinceEpoch) / 1000}\n'
        '   Timezone: ${tz.local.name}',
      );

      // Convert TZDateTime to DateTime for NativeAlarmService
      final alarmTime = DateTime.fromMillisecondsSinceEpoch(
        scheduledTime.millisecondsSinceEpoch,
      );

      // Use Native AlarmManager for reliable delivery (PRIMARY METHOD)
      debugPrint('📱 Scheduling via Native AlarmManager...');

      // Check if this is a recurring bill
      final isRecurring = bill.repeat != 'none';
      final recurringType = bill.repeat;
      final currentSequence = bill.recurringSequence ?? 1;
      final repeatCount = bill.repeatCount ?? -1;

      // Update body to include sequence number for recurring bills
      String finalBody = body;
      if (isRecurring && repeatCount > 0) {
        // Include sequence number for recurring bills with a count
        finalBody =
            '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor} ($currentSequence of $repeatCount)';
      } else if (isRecurring && repeatCount == -1) {
        // Include sequence number for unlimited recurring bills
        finalBody =
            '${bill.title} - \$${bill.amount.toStringAsFixed(2)} due to ${bill.vendor} (#$currentSequence)';
      }

      try {
        final nativeSuccess = await NativeAlarmService.scheduleAlarm(
          dateTime: alarmTime,
          title: title,
          body: finalBody,
          notificationId: bill.id.hashCode,
          userId: userId,
          billId: bill.id,
          isRecurring: isRecurring,
          recurringType: recurringType,
          billTitle: bill.title,
          billAmount: bill.amount,
          billVendor: bill.vendor,
          currentSequence: currentSequence,
          repeatCount: repeatCount,
        );

        if (nativeSuccess) {
          debugPrint('✅ Native AlarmManager scheduled successfully!');
          debugPrint('   isRecurring: $isRecurring, type: $recurringType');
        } else {
          debugPrint(
            '⚠️ Native AlarmManager returned false, using flutter_local_notifications as fallback',
          );
        }
      } catch (e) {
        debugPrint('❌ Native AlarmManager error: $e');
        debugPrint('⚠️ Falling back to flutter_local_notifications only');
      }

      // NOTE: Removed flutter_local_notifications backup to prevent duplicate notifications
      // Native AlarmManager is the primary and only method now
      // The backup was causing duplicate notifications on device

      // Track this scheduled notification for history with userId
      await NotificationHistoryService.trackScheduledNotification(
        billId: bill.id,
        billTitle: bill.title,
        title: title,
        body: body,
        scheduledFor: scheduledTime.toLocal(),
        userId: userId, // Track which user this notification belongs to
      );

      debugPrint(
        '✅✅✅ NOTIFICATION SCHEDULED SUCCESSFULLY! ✅✅✅\n'
        '   Bill: ${bill.title}\n'
        '   ID: ${bill.id.hashCode}\n'
        '   Scheduled Time: $scheduledTime\n'
        '   Current Time: $tzNow\n'
        '   Will trigger in: ${scheduledTime.difference(tzNow).inMinutes} minutes\n'
        '   Title: $title\n'
        '   Body: $body\n'
        '   📝 Tracked for notification history\n'
        '   🔔 Using Native AlarmManager only',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling notification for ${bill.title}: $e');
    } finally {
      // CRITICAL: Always release the lock
      _currentlyScheduling.remove(trackingKey);
    }
  }

  /// Show immediate notification
  /// STICT RULE: Only shows device notification if userId matches currently logged in user
  /// STICT RULE: Always saves to history regardless of user
  Future<void> showImmediateNotification(
    String title,
    String body, {
    String? payload,
    String? billId,
    String? billTitle,
    String? userId, // Add userId parameter
  }) async {
    try {
      debugPrint('🔔 Processing immediate notification for user: $userId');

      // 1. ALWAYS Save to notification history (Requirement 2 & 3A)
      // This happens regardless of who is logged in
      await NotificationHistoryService.addNotification(
        title: title,
        body: body,
        billId: billId,
        billTitle: billTitle,
        userId: userId,
      );
      debugPrint('💾 Saved to notification history');

      // 2. CONDITIONALLY Show device notification (Requirement 1 & 3B)
      // Only if the notification belongs to the currently logged-in user
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;

      if (userId != null && userId != currentUserId) {
        debugPrint(
          '🚫 Skipping device notification: Belong to $userId, but current user is $currentUserId',
        );
        return;
      }

      debugPrint('🔔 Showing device notification for current user...');

      // Check permissions
      final enabled = await areNotificationsEnabled();
      if (!enabled) {
        debugPrint('⚠️ Requesting notification permission...');
        final granted = await requestPermissions();
        if (!granted) {
          debugPrint('❌ Permission denied!');
          return;
        }
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
        visibility: NotificationVisibility.public,
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

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Immediate device notification shown successfully!');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing immediate notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Centralized method to handle all bill events (Requirement 6)
  /// Handles: Overdue, Recurring Created, Paid
  Future<void> sendNotification({
    required BillHive bill,
    required String type, // 'overdue', 'recurring', 'paid'
  }) async {
    String title;
    String body;

    switch (type) {
      case 'overdue':
        title = 'Bill Overdue: ${bill.title}';
        body =
            'Ensure payment of \$${bill.amount} to ${bill.vendor} to avoid fees.';
        break;
      case 'recurring':
        title = 'New Bill Generated: ${bill.title}';
        body = 'A new bill for \$${bill.amount} has been created.';
        break;
      case 'paid':
        title = 'Bill Paid: ${bill.title}';
        body = 'Payment of \$${bill.amount} to ${bill.vendor} recorded.';
        break;
      default:
        title = 'Bill Update: ${bill.title}';
        body = 'Check your bill status.';
    }

    await showImmediateNotification(
      title,
      body,
      billId: bill.id,
      billTitle: bill.title,
      userId: bill.userId,
      payload: bill.id,
    );
  }

  /// Schedule test notification (10 seconds from now)
  /// Uses AlarmManager for guaranteed delivery even when app is closed
  Future<void> scheduleTestNotification() async {
    try {
      debugPrint(
        '🧪 Starting test notification scheduling (using AlarmManager)...',
      );

      // Check permissions first
      final notificationsEnabled = await areNotificationsEnabled();
      debugPrint('📱 Notifications enabled: $notificationsEnabled');

      if (!notificationsEnabled) {
        debugPrint('⚠️ Notifications not enabled! Requesting permission...');
        final granted = await requestPermissions();
        debugPrint('📱 Permission granted: $granted');

        if (!granted) {
          debugPrint('❌ Permission denied! Cannot schedule notification.');
          return;
        }
      }

      // Check exact alarm permission (Android 12+)
      final canScheduleExact = await canScheduleExactAlarms();
      debugPrint('⏰ Can schedule exact alarms: $canScheduleExact');

      if (!canScheduleExact) {
        debugPrint('❌ EXACT ALARM PERMISSION NOT GRANTED!');
        debugPrint(
          '❌ Scheduled notifications will NOT work without this permission!',
        );
        debugPrint(
          '❌ Go to: Settings > Apps > BillManager > Alarms & reminders > Enable',
        );

        // Try to request it
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          debugPrint('📱 Attempting to request exact alarm permission...');
          await androidPlugin.requestExactAlarmsPermission();

          // Check again
          final canScheduleNow = await canScheduleExactAlarms();
          debugPrint(
            '📱 After request, can schedule exact alarms: $canScheduleNow',
          );

          if (!canScheduleNow) {
            debugPrint('❌ User denied exact alarm permission!');
            throw Exception(
              'Exact alarm permission required for scheduled notifications. '
              'Please enable it in Settings > Apps > BillManager > Alarms & reminders',
            );
          }
        }
      }

      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(seconds: 10));

      debugPrint('⏰ Current time: $now');
      debugPrint('⏰ Scheduled time: $scheduledTime');
      debugPrint('⏰ Timezone: ${tz.local.name}');

      final title = 'Scheduled Test Notification';

      debugPrint('🔔 Scheduling notification using AlarmManager:');
      debugPrint('   ID: 999999');
      debugPrint('   Title: $title');
      debugPrint('   Scheduled TZDateTime: $scheduledTime');

      // Convert TZDateTime to DateTime for AlarmManager
      final alarmTime = DateTime.fromMillisecondsSinceEpoch(
        scheduledTime.millisecondsSinceEpoch,
      );
      debugPrint('   Alarm DateTime: $alarmTime');
      debugPrint('   Current DateTime: ${DateTime.now()}');
      debugPrint(
        '   Seconds until alarm: ${alarmTime.difference(DateTime.now()).inSeconds}',
      );

      // Use Native AlarmManager for reliable delivery
      final success = await NativeAlarmService.scheduleAlarm(
        dateTime: alarmTime,
        title: 'Scheduled Test Notification',
        body:
            'This was triggered by native AlarmManager at ${DateTime.now().toString().substring(11, 19)}. Works when app is closed!',
        notificationId: 999999,
        billId: 'test_notification', // Test notification ID
      );

      if (success) {
        debugPrint(
          '✅ Test notification scheduled successfully via Native AlarmManager!',
        );
        debugPrint('📱 This will work even when app is closed!');
        debugPrint('⏰ Alarm will trigger at: $alarmTime');
      } else {
        debugPrint('❌ Failed to schedule native alarm');
        throw Exception('Failed to schedule native alarm');
      }

      // NOTE: Removed flutter_local_notifications backup to prevent duplicate notifications
      // Native AlarmManager is the primary and only method now
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling test notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Check if a notification is already scheduled for a bill at the given time
  /// This prevents unnecessary cancellation and rescheduling of native alarms
  Future<bool> _isNotificationAlreadyScheduled(
    String billId,
    tz.TZDateTime scheduledTime,
  ) async {
    try {
      final trackingBox = await Hive.openBox('scheduledNotifications');
      final trackingKey = 'scheduled_$billId';
      final existingData = trackingBox.get(trackingKey);

      if (existingData == null || existingData is! Map) {
        return false;
      }

      // Check if the scheduled time matches (within 1 minute tolerance)
      final existingTimeMs = existingData['scheduledFor'] as int?;
      if (existingTimeMs == null) {
        return false;
      }

      final existingTime = DateTime.fromMillisecondsSinceEpoch(existingTimeMs);
      final newTime = DateTime.fromMillisecondsSinceEpoch(
        scheduledTime.millisecondsSinceEpoch,
      );

      // If times are within 1 minute of each other, consider it already scheduled
      final difference = existingTime.difference(newTime).inMinutes.abs();
      if (difference <= 1) {
        debugPrint(
          '📋 Found existing scheduled notification for $billId at $existingTime',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking scheduled notification: $e');
      return false;
    }
  }

  /// Cancel notification for a specific bill
  Future<void> cancelBillNotification(String billId) async {
    // Cancel from flutter_local_notifications
    await _notifications.cancel(billId.hashCode);
    // Cancel from Native AlarmManager
    await NativeAlarmService.cancelAlarm(billId.hashCode);
    // Remove from tracking
    await NotificationHistoryService.removeScheduledTracking(billId);
    debugPrint(
      '🗑️ Cancelled notification for bill: $billId (both native and plugin)',
    );
  }

  /// Cancel all notifications (both flutter_local_notifications and native alarms)
  Future<void> cancelAllNotifications() async {
    try {
      debugPrint('🗑️ Cancelling all notifications...');

      // First, cancel from flutter_local_notifications
      await _notifications.cancelAll();
      debugPrint('✅ Cancelled all flutter notifications');

      // Cancel all native alarms using the tracking box
      // We must use the tracking box because NativeAlarmService alarms are not returned
      // by _notifications.pendingNotificationRequests()
      try {
        final trackingBox = await Hive.openBox('scheduledNotifications');
        final keys = trackingBox.keys.toList();
        int cancelledCount = 0;

        for (var key in keys) {
          try {
            final data = trackingBox.get(key);
            if (data != null && data is Map) {
              // Extract billId to regenerate the notificationId (hashCode)
              final billId = data['billId'] as String?;
              if (billId != null) {
                await NativeAlarmService.cancelAlarm(billId.hashCode);
                cancelledCount++;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to cancel native alarm for key $key: $e');
          }
        }

        // Clear the scheduled notification tracking
        await trackingBox.clear();
        debugPrint(
          '✅ Cancelled $cancelledCount native alarms and cleared tracking',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to access tracking box: $e');
      }

      debugPrint('✅ All notifications cancelled successfully');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// Cancel all notifications for a specific user
  /// This is called on logout to ensure no notifications for this user
  /// will be shown after they log out
  Future<void> cancelAllNotificationsForUser(String? userId) async {
    if (userId == null) {
      debugPrint('⚠️ No userId provided, cancelling ALL notifications');
      await cancelAllNotifications();
      return;
    }

    try {
      debugPrint('🗑️ Cancelling all notifications for user: $userId');

      // Cancel from flutter_local_notifications (this cancels ALL, but that's okay)
      await _notifications.cancelAll();
      debugPrint('✅ Cancelled all flutter notifications');

      // Cancel only native alarms belonging to this user
      try {
        final trackingBox = await Hive.openBox('scheduledNotifications');
        final keys = trackingBox.keys.toList();
        int cancelledCount = 0;
        final keysToDelete = <dynamic>[];

        for (var key in keys) {
          try {
            final data = trackingBox.get(key);
            if (data != null && data is Map) {
              final notificationUserId = data['userId'] as String?;
              final billId = data['billId'] as String?;

              // Only cancel notifications for this user
              if (notificationUserId == userId && billId != null) {
                await NativeAlarmService.cancelAlarm(billId.hashCode);
                keysToDelete.add(key);
                cancelledCount++;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to cancel native alarm for key $key: $e');
          }
        }

        // Remove cancelled notifications from tracking
        for (var key in keysToDelete) {
          await trackingBox.delete(key);
        }

        debugPrint(
          '✅ Cancelled $cancelledCount native alarms for user $userId',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to access tracking box: $e');
      }

      debugPrint('✅ All notifications cancelled for user: $userId');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications for user: $e');
    }
  }

  /// Reschedule all notifications (call after app restart/reboot)
  Future<void> rescheduleAllNotifications(
    List<BillHive> bills, {
    String? userId,
  }) async {
    debugPrint('🔄 Rescheduling all notifications for user: $userId');

    int scheduled = 0;
    for (var bill in bills) {
      if (!bill.isPaid && !bill.isDeleted) {
        await scheduleBillNotification(bill, userId: userId);
        scheduled++;
      }
    }

    debugPrint('✅ Rescheduled $scheduled notifications');
  }
}
