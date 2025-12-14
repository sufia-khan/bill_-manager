import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'sync_service.dart';
import 'notification_service.dart';
import 'notification_history_service.dart';

/// Result of account deletion operation
class AccountDeletionResult {
  final bool success;
  final String? error;
  final bool wasOffline;

  AccountDeletionResult({
    required this.success,
    this.error,
    this.wasOffline = false,
  });
}

/// Service for handling complete account deletion
/// CRITICAL: The order of operations matters for permanent deletion:
/// 1. Stop sync to prevent data recreation
/// 2. Cancel notifications
/// 3. Delete CLOUD data first (while we still have valid auth)
/// 4. Delete Firebase Auth account (BEFORE signing out)
/// 5. Sign out from Google (to clear tokens)
/// 6. Delete LOCAL data
/// 7. Clear SharedPreferences
class AccountService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Delete account completely - cloud first (while authenticated), then local
  /// Returns AccountDeletionResult with success status and any errors
  static Future<AccountDeletionResult> deleteAccount() async {
    debugPrint('\n🗑️ ========== ACCOUNT DELETION STARTED ==========');
    final stopwatch = Stopwatch()..start();

    final user = _auth.currentUser;
    final userId = user?.uid;

    if (userId == null || user == null) {
      debugPrint('❌ No user logged in');
      return AccountDeletionResult(success: false, error: 'No user logged in');
    }

    debugPrint('👤 Deleting account for user: $userId');

    // Check if online - required for cloud deletion
    final online = await isOnline();
    if (!online) {
      debugPrint('❌ Device is offline - cannot delete account');
      return AccountDeletionResult(
        success: false,
        error: 'Connect to the internet to delete your account.',
        wasOffline: true,
      );
    }

    try {
      // STEP 1: Stop all sync operations FIRST to prevent data recreation
      debugPrint('🛑 Step 1: Stopping sync operations...');
      SyncService.stopPeriodicSync();
      debugPrint(
        '✅ Sync operations stopped (${stopwatch.elapsedMilliseconds}ms)',
      );

      // STEP 2: Cancel ALL scheduled notifications (parallel with cloud deletion)
      debugPrint('🔕 Step 2: Cancelling all notifications...');
      final notificationFuture = _cancelAllNotifications();

      // STEP 3: Delete all CLOUD data FIRST (while we still have valid auth)
      // This is the CRITICAL step - if this succeeds, data is permanently gone
      // Use timeout to handle slow networks
      debugPrint('☁️ Step 3: Deleting cloud data (30 second timeout)...');
      await _deleteAllCloudData(userId).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Cloud deletion timed out. Please check your network and try again.',
          );
        },
      );
      debugPrint('✅ Cloud data deleted (${stopwatch.elapsedMilliseconds}ms)');

      // Cloud deletion succeeded - this is the point of no return
      // Even if subsequent steps fail, the account data is permanently gone from Firestore

      // Wait for notifications to be cancelled
      await notificationFuture;
      debugPrint(
        '✅ All notifications cancelled (${stopwatch.elapsedMilliseconds}ms)',
      );

      // STEP 4: Delete Firebase Auth account BEFORE signing out
      // CRITICAL: We must delete the account while we still have a valid user reference
      debugPrint('🔐 Step 4: Deleting Firebase Auth account...');
      await _deleteFirebaseAuthAccount(user);
      debugPrint(
        '✅ Firebase Auth account handled (${stopwatch.elapsedMilliseconds}ms)',
      );

      // STEP 5: Sign out from Google (clear tokens)
      debugPrint('🔓 Step 5: Signing out from Google...');
      await _signOutFromGoogle();
      debugPrint(
        '✅ Signed out from Google (${stopwatch.elapsedMilliseconds}ms)',
      );

      // STEP 6: Delete all LOCAL data (Hive boxes) - NON-CRITICAL
      // If this fails, the account is still deleted, just local cache remains
      debugPrint('💾 Step 6: Deleting local data...');
      try {
        await _deleteAllLocalData();
        debugPrint('✅ Local data deleted (${stopwatch.elapsedMilliseconds}ms)');
      } catch (localError) {
        debugPrint('⚠️ Local data cleanup failed: $localError');
        debugPrint('   (Account is still deleted, continuing...)');
      }

      // STEP 7: Clear SharedPreferences - NON-CRITICAL
      debugPrint('🧹 Step 7: Clearing SharedPreferences...');
      try {
        await _clearSharedPreferences();
        debugPrint(
          '✅ SharedPreferences cleared (${stopwatch.elapsedMilliseconds}ms)',
        );
      } catch (prefError) {
        debugPrint('⚠️ SharedPreferences cleanup failed: $prefError');
      }

      stopwatch.stop();
      debugPrint('✅✅✅ ACCOUNT DELETION COMPLETED SUCCESSFULLY ✅✅✅');
      debugPrint('⏱️ Total time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('================================================\n');

      return AccountDeletionResult(success: true);
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '❌ Account deletion failed at ${stopwatch.elapsedMilliseconds}ms: $e',
      );
      debugPrint('Stack trace: $stackTrace');
      debugPrint('================================================\n');

      // Check if this is a network/timeout error - DON'T sign out so user can retry
      final errorStr = e.toString().toLowerCase();
      final isNetworkError =
          errorStr.contains('timeout') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket') ||
          errorStr.contains('timed out');

      if (!isNetworkError) {
        // Only sign out for non-network errors to prevent stuck state
        try {
          await _signOutFromGoogle();
          await _auth.signOut();
        } catch (_) {}
      } else {
        debugPrint(
          '⚠️ Network error detected - keeping user signed in for retry',
        );
      }

      return AccountDeletionResult(
        success: false,
        error: e.toString(),
        wasOffline: isNetworkError,
      );
    }
  }

  /// Cancel all scheduled notifications and clear notification history
  static Future<void> _cancelAllNotifications() async {
    try {
      // Get current user ID for proper cleanup
      final userId = _auth.currentUser?.uid;

      // Cancel all scheduled notifications (both native alarms and flutter notifications)
      await NotificationService().cancelAllNotifications();
      debugPrint('  ✓ Scheduled notifications cancelled');

      // Clear notification history (both Hive and Firestore)
      await NotificationHistoryService.clearAll(userId: userId);
      debugPrint('  ✓ Notification history cleared from Hive and Firestore');

      // Clear native Android SharedPreferences
      try {
        await _clearNativeSharedPreferences();
        debugPrint('  ✓ Native SharedPreferences cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing native SharedPreferences: $e');
        // Continue - this is best effort
      }
    } catch (e) {
      debugPrint('  ⚠️ Error cancelling notifications: $e');
      // Continue with deletion even if notification cancellation fails
    }
  }

  /// Clear native Android SharedPreferences used by AlarmReceiver
  static Future<void> _clearNativeSharedPreferences() async {
    try {
      const platform = MethodChannel('com.example.bill_manager/prefs');

      // Clear notification_history (pending notifications)
      await platform.invokeMethod('clearPendingNotifications');

      // Clear pending_recurring_bills
      await platform.invokeMethod('clearPendingRecurringBills');

      debugPrint(
        '    ✓ Cleared notification_history and pending_recurring_bills',
      );
    } catch (e) {
      debugPrint('    ⚠️ Error clearing native prefs: $e');
      rethrow;
    }
  }

  /// Delete all local data from Hive boxes
  static Future<void> _deleteAllLocalData() async {
    try {
      // Use HiveService.clearAllData() for properly typed boxes (bills and user)
      // This avoids the "box is already open and of type Box<BillHive>" error
      await HiveService.clearAllData();
      debugPrint('  ✓ Bills and user boxes cleared via HiveService');

      // Clear additional boxes in parallel for speed
      final futures = <Future>[];

      // Clear scheduled notifications tracking box
      try {
        if (Hive.isBoxOpen('scheduledNotifications')) {
          futures.add(
            Hive.box('scheduledNotifications').clear().then((_) {
              debugPrint('  ✓ Scheduled notifications box cleared');
            }),
          );
        }
      } catch (_) {}

      // Clear notification history box
      try {
        if (Hive.isBoxOpen('notificationHistory')) {
          futures.add(
            Hive.box('notificationHistory').clear().then((_) {
              debugPrint('  ✓ Notification history box cleared');
            }),
          );
        }
      } catch (_) {}

      // Clear user preferences box
      try {
        if (Hive.isBoxOpen('userPreferences')) {
          futures.add(
            Hive.box('userPreferences').clear().then((_) {
              debugPrint('  ✓ User preferences box cleared');
            }),
          );
        }
      } catch (_) {}

      // Clear pending notifications box
      try {
        if (Hive.isBoxOpen('pendingNotifications')) {
          futures.add(
            Hive.box('pendingNotifications').clear().then((_) {
              debugPrint('  ✓ Pending notifications box cleared');
            }),
          );
        }
      } catch (_) {}

      // Wait for all additional box clears to complete
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      debugPrint('  ✓ All local data cleared');
    } catch (e) {
      debugPrint('  ⚠️ Error clearing local data: $e');
      rethrow;
    }
  }

  /// Delete all cloud data from Firestore
  /// Handles batch deletion for large datasets (500 docs per batch)
  static Future<void> _deleteAllCloudData(String userId) async {
    try {
      // Delete all bills in users/{userId}/bills
      await _deleteCollection('users/$userId/bills');
      debugPrint('  ✓ Bills collection deleted from Firestore');

      // Delete the user document itself
      await _firestore.collection('users').doc(userId).delete();
      debugPrint('  ✓ User document deleted from Firestore');
    } catch (e) {
      debugPrint('  ⚠️ Error deleting cloud data: $e');
      rethrow;
    }
  }

  /// Delete a Firestore collection in batches of 500
  static Future<void> _deleteCollection(String path) async {
    const batchSize = 500;
    final collectionRef = _firestore.collection(path);

    while (true) {
      // Get a batch of documents
      final snapshot = await collectionRef.limit(batchSize).get();

      if (snapshot.docs.isEmpty) {
        break; // No more documents to delete
      }

      // Create a batch delete
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();
      debugPrint('    Deleted ${snapshot.docs.length} documents from $path');

      // If we got fewer than batchSize, we're done
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }

  /// Delete Firebase Auth account
  /// CRITICAL: Must be called BEFORE signing out from Google
  /// The user reference must still be valid for deletion to work
  static Future<void> _deleteFirebaseAuthAccount(User user) async {
    try {
      // Attempt to delete the Firebase Auth account directly
      // This requires recent authentication (within last 5 minutes typically)
      await user.delete();
      debugPrint('  ✓ Firebase Auth account deleted permanently');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint(
          '  ⚠️ Requires recent login - attempting re-authentication...',
        );

        // Try to re-authenticate with Google
        try {
          final reauthed = await _reauthenticateWithGoogle(user);
          if (reauthed) {
            // Try deletion again after re-authentication
            await user.delete();
            debugPrint('  ✓ Firebase Auth account deleted after re-auth');
          } else {
            debugPrint(
              '  ⚠️ Re-auth failed - account remains but data is deleted',
            );
            // Data is already deleted, so account is essentially orphaned
            // Just sign out
          }
        } catch (reAuthError) {
          debugPrint('  ⚠️ Re-auth error: $reAuthError');
          // Continue - data is already deleted
        }
      } else {
        debugPrint(
          '  ⚠️ Firebase Auth deletion error: ${e.code} - ${e.message}',
        );
        // Don't rethrow - data is already deleted, account deletion is best-effort
      }
    } catch (e) {
      debugPrint('  ⚠️ Unexpected error deleting Firebase Auth account: $e');
      // Don't rethrow - data is already deleted
    }
  }

  /// Re-authenticate with Google for sensitive operations
  static Future<bool> _reauthenticateWithGoogle(User user) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);

      // Try silent sign-in first (faster)
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();

      // If silent sign-in fails, prompt user
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('    Re-auth cancelled by user');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('    ✓ Re-authenticated successfully');
      return true;
    } catch (e) {
      debugPrint('    ✗ Re-authentication failed: $e');
      return false;
    }
  }

  /// Sign out from Google to clear tokens
  static Future<void> _signOutFromGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);

      // Disconnect to revoke access
      try {
        await googleSignIn.disconnect();
        debugPrint('  ✓ Google disconnected');
      } catch (e) {
        // Try simple sign out as fallback
        try {
          await googleSignIn.signOut();
          debugPrint('  ✓ Google signed out (fallback)');
        } catch (_) {}
      }

      // Sign out from Firebase Auth
      await _auth.signOut();
      debugPrint('  ✓ Firebase Auth signed out');
    } catch (e) {
      debugPrint('  ⚠️ Error signing out: $e');
      // Continue even if sign out fails
    }
  }

  /// Clear SharedPreferences
  static Future<void> _clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear all user-related preferences
      await prefs.remove('currentUserId');
      await prefs.remove(
        'flutter.currentUserId',
      ); // Also clear flutter-prefixed key
      debugPrint('  ✓ currentUserId removed from SharedPreferences');
    } catch (e) {
      debugPrint('  ⚠️ Error clearing SharedPreferences: $e');
      // Continue even if this fails
    }
  }
}
