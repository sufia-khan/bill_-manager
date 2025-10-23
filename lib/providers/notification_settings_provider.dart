import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationSettingsProvider with ChangeNotifier {
  static const String _boxName = 'notificationSettings';
  static const String _reminderTimingKey = 'reminderTiming';
  static const String _notificationTimeKey = 'notificationTime';
  static const String _notificationsEnabledKey = 'notificationsEnabled';

  Box? _box;
  bool _isInitialized = false;

  // Default values
  String _reminderTiming =
      'Same Day'; // 'Same Day', '1 Day Before', '2 Days Before', '1 Week Before'
  TimeOfDay _notificationTime = const TimeOfDay(
    hour: 9,
    minute: 0,
  ); // Default 9:00 AM
  bool _notificationsEnabled = true; // Default enabled

  String get reminderTiming => _reminderTiming;
  TimeOfDay get notificationTime => _notificationTime;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox(_boxName);
      await _loadSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notification settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    if (_box == null) return;

    try {
      // Load reminder timing
      final savedReminderTiming = _box!.get(_reminderTimingKey);
      if (savedReminderTiming != null) {
        _reminderTiming = savedReminderTiming as String;
      }

      // Load notification time
      final savedTime = _box!.get(_notificationTimeKey);
      if (savedTime != null) {
        final parts = (savedTime as String).split(':');
        if (parts.length == 2) {
          _notificationTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }

      // Load notifications enabled state
      final savedEnabled = _box!.get(_notificationsEnabledKey);
      if (savedEnabled != null) {
        _notificationsEnabled = savedEnabled as bool;
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> setReminderTiming(String timing) async {
    if (_box == null) return;

    try {
      _reminderTiming = timing;
      await _box!.put(_reminderTimingKey, timing);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving reminder timing: $e');
    }
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    if (_box == null) return;

    try {
      _notificationTime = time;
      final timeString = '${time.hour}:${time.minute}';
      await _box!.put(_notificationTimeKey, timeString);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving notification time: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_box == null) return;

    try {
      _notificationsEnabled = enabled;
      await _box!.put(_notificationsEnabledKey, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving notifications enabled state: $e');
    }
  }

  int getReminderDaysOffset() {
    switch (_reminderTiming) {
      case '1 Day Before':
        return 1;
      case '2 Days Before':
        return 2;
      case '1 Week Before':
        return 7;
      case 'Same Day':
      default:
        return 0;
    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
