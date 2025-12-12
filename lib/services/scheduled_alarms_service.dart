import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to store scheduled alarms in SharedPreferences
/// This allows native code to access alarm data even when Flutter app is killed
class ScheduledAlarmsService {
  static const String _alarmsKey = 'scheduled_alarms';
  static const platform = MethodChannel('com.example.bill_manager/prefs');

  /// Store a scheduled alarm
  static Future<void> storeAlarm({
    required String billId,
    required int notificationId,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? userId,
    bool isRecurring = false,
    String? recurringType,
    String? billTitle,
    double? billAmount,
    String? billVendor,
    int currentSequence = 1,
    int repeatCount = -1,
    String alarmType = 'reminder', // 'reminder' or 'due'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing alarms
      final existingData = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = List<Map<String, dynamic>>.from(json.decode(existingData));

      // Remove any existing alarm with same billId and alarmType
      alarms.removeWhere(
        (a) =>
            a['billId'] == billId &&
            a['alarmType'] == alarmType &&
            a['currentSequence'] == currentSequence,
      );

      // Add new alarm
      alarms.add({
        'billId': billId,
        'notificationId': notificationId,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'userId': userId ?? '',
        'isRecurring': isRecurring,
        'recurringType': recurringType ?? '',
        'billTitle': billTitle ?? '',
        'billAmount': billAmount ?? 0.0,
        'billVendor': billVendor ?? '',
        'currentSequence': currentSequence,
        'repeatCount': repeatCount,
        'alarmType': alarmType,
      });

      await prefs.setString(_alarmsKey, json.encode(alarms));
      debugPrint(
        '💾 Stored alarm for $billTitle seq:$currentSequence at $scheduledTime',
      );
    } catch (e) {
      debugPrint('❌ Error storing alarm: $e');
    }
  }

  /// Remove a scheduled alarm
  static Future<void> removeAlarm(
    String billId, {
    String? alarmType,
    int? sequence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final existingData = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = List<Map<String, dynamic>>.from(json.decode(existingData));

      alarms.removeWhere((a) {
        final matchBill = a['billId'] == billId;
        final matchType = alarmType == null || a['alarmType'] == alarmType;
        final matchSeq = sequence == null || a['currentSequence'] == sequence;
        return matchBill && matchType && matchSeq;
      });

      await prefs.setString(_alarmsKey, json.encode(alarms));
      debugPrint('🗑️ Removed alarm for $billId');
    } catch (e) {
      debugPrint('❌ Error removing alarm: $e');
    }
  }

  /// Remove all alarms for a bill
  static Future<void> removeAllAlarmsForBill(String billId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final existingData = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = List<Map<String, dynamic>>.from(json.decode(existingData));

      final initialCount = alarms.length;
      alarms.removeWhere((a) => a['billId'] == billId);

      await prefs.setString(_alarmsKey, json.encode(alarms));
      debugPrint(
        '🗑️ Removed ${initialCount - alarms.length} alarms for bill $billId',
      );
    } catch (e) {
      debugPrint('❌ Error removing alarms: $e');
    }
  }

  /// Get all scheduled alarms
  static Future<List<Map<String, dynamic>>> getAllAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_alarmsKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(existingData));
    } catch (e) {
      debugPrint('❌ Error getting alarms: $e');
      return [];
    }
  }

  /// Clear all stored alarms
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_alarmsKey, '[]');
      debugPrint('🧹 Cleared all stored alarms');
    } catch (e) {
      debugPrint('❌ Error clearing alarms: $e');
    }
  }

  /// Clear all alarms for a user (on logout)
  static Future<void> clearAlarmsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final existingData = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = List<Map<String, dynamic>>.from(json.decode(existingData));

      alarms.removeWhere((a) => a['userId'] == userId);

      await prefs.setString(_alarmsKey, json.encode(alarms));
      debugPrint('🧹 Cleared alarms for user $userId');
    } catch (e) {
      debugPrint('❌ Error clearing user alarms: $e');
    }
  }
}
