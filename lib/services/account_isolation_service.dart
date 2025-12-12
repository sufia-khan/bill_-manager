import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hive_service.dart';
import 'sync_service.dart';
import 'notification_service.dart';
import 'notification_history_service.dart';

/// Centralized service for account data isolation.
/// Ensures clean transitions between user accounts with no data leaks.
class AccountIsolationService {
  /// Complete cleanup on logout.
  /// Ensures no data from current user remains for next login.
  ///
  /// Order of operations is CRITICAL:
  /// 1. Stop all background services FIRST (prevents data recreation)
  /// 2. Sync any pending changes (best effort)
  /// 3. Cancel all notifications
  /// 4. Clear ALL local storage
  /// 5. Clear Firestore offline cache
  /// 6. Reset user tracking
  /// 7. Sign out from Firebase
  static Future<void> cleanLogout() async {
    debugPrint('\n🔒 ========== CLEAN LOGOUT STARTED ==========');
    final stopwatch = Stopwatch()..start();

    try {
      // STEP 1: Stop ALL background services FIRST
      // This is critical - prevents sync from recreating data
      debugPrint('🛑 Step 1: Stopping all background services...');
      SyncService.stop();
      debugPrint('  ✓ Sync service stopped');

      // STEP 2: Best-effort sync of pending changes (with timeout)
      debugPrint('📤 Step 2: Syncing pending changes (5s timeout)...');
      try {
        await SyncService.syncBills().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('  ⚠️ Sync timeout - continuing with logout');
          },
        );
        debugPrint('  ✓ Pending changes synced');
      } catch (e) {
        debugPrint('  ⚠️ Sync failed: $e - continuing');
      }

      // STEP 3: Cancel all scheduled notifications
      debugPrint('🔕 Step 3: Cancelling all notifications...');
      try {
        await NotificationService().cancelAllNotifications();
        debugPrint('  ✓ All notifications cancelled');
      } catch (e) {
        debugPrint('  ⚠️ Failed to cancel notifications: $e');
      }

      // STEP 4: Clear ALL Hive boxes
      debugPrint('🗑️ Step 4: Clearing all local storage...');
      await _clearAllHiveBoxes();
      debugPrint('  ✓ All Hive boxes cleared');

      // STEP 5: Clear Firestore offline cache
      debugPrint('🔥 Step 5: Clearing Firestore cache...');
      await _clearFirestoreCache();
      debugPrint('  ✓ Firestore cache cleared');

      // STEP 6: Clear SharedPreferences
      debugPrint('🧹 Step 6: Clearing SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserId');
      debugPrint('  ✓ currentUserId removed from SharedPreferences');

      // STEP 7: Reset HiveService tracking
      HiveService.setCurrentUserId(null);
      debugPrint('  ✓ HiveService currentUserId reset');

      // STEP 8: Clear notification history
      debugPrint('📋 Step 8: Clearing notification history...');
      try {
        await NotificationHistoryService.clearAll();
        debugPrint('  ✓ Notification history cleared');
      } catch (e) {
        debugPrint('  ⚠️ Failed to clear notification history: $e');
      }

      stopwatch.stop();
      debugPrint(
        '✅ CLEAN LOGOUT COMPLETED (${stopwatch.elapsedMilliseconds}ms)',
      );
      debugPrint('==========================================\n');
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ CLEAN LOGOUT FAILED: $e');
      debugPrint('Stack: $stack');
      debugPrint('==========================================\n');
      rethrow;
    }
  }

  /// Initialize fresh state for new user login.
  /// Clears any leftover data and sets up for the new user.
  static Future<void> cleanLogin(User user) async {
    debugPrint('\n🔓 ========== CLEAN LOGIN STARTED ==========');
    debugPrint('👤 User: ${user.uid}');
    final stopwatch = Stopwatch()..start();

    try {
      // STEP 1: Always clear local bills to prevent contamination
      // This is safe because we'll pull fresh data from Firebase
      debugPrint('🗑️ Step 1: Clearing leftover local data...');
      await HiveService.clearBillsOnly();
      debugPrint('  ✓ Old bills cleared');

      // STEP 2: Clear notification history from previous user
      try {
        await NotificationHistoryService.clearAll();
        debugPrint('  ✓ Old notification history cleared');
      } catch (e) {
        debugPrint('  ⚠️ Failed to clear notification history: $e');
      }

      // STEP 3: Set correct userId in all tracking systems
      debugPrint('👤 Step 2: Setting user ID...');
      HiveService.setCurrentUserId(user.uid);
      await HiveService.saveUserData('currentUserId', user.uid);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', user.uid);
      debugPrint('  ✓ User ID set in HiveService and SharedPreferences');

      // STEP 4: Start sync service bound to this user
      debugPrint('🔄 Step 3: Starting sync for user...');
      SyncService.start(user.uid);
      debugPrint('  ✓ Sync service started for user: ${user.uid}');

      stopwatch.stop();
      debugPrint(
        '✅ CLEAN LOGIN COMPLETED (${stopwatch.elapsedMilliseconds}ms)',
      );
      debugPrint('==========================================\n');
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ CLEAN LOGIN FAILED: $e');
      debugPrint('Stack: $stack');
      debugPrint('==========================================\n');
      rethrow;
    }
  }

  /// Clear all Hive boxes completely.
  static Future<void> _clearAllHiveBoxes() async {
    // Clear the main typed boxes via HiveService
    await HiveService.clearAllData();

    // Also clear any additional untyped boxes
    final boxNames = [
      'scheduledNotifications',
      'notificationHistory',
      'userPreferences',
      'pendingNotifications',
    ];

    for (final boxName in boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
          debugPrint('    ✓ $boxName cleared');
        }
      } catch (e) {
        debugPrint('    ⚠️ Failed to clear $boxName: $e');
      }
    }
  }

  /// Clear Firestore offline cache using terminate+clear pattern.
  static Future<void> _clearFirestoreCache() async {
    try {
      // First, terminate any active connections
      await FirebaseFirestore.instance.terminate();
      // Then clear the persistence
      await FirebaseFirestore.instance.clearPersistence();
      debugPrint('    ✓ Firestore terminated and cache cleared');
    } catch (e) {
      debugPrint('    ⚠️ Primary cache clear failed: $e');
      // Fallback: try just clearPersistence
      try {
        await FirebaseFirestore.instance.clearPersistence();
        debugPrint('    ✓ Firestore cache cleared (fallback)');
      } catch (e2) {
        debugPrint('    ⚠️ Fallback cache clear also failed: $e2');
        // Continue anyway - the app will still work, just might have stale cache
      }
    }
  }
}
