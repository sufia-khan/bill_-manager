import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../services/user_preferences_service.dart';
import '../services/notification_service.dart';
import '../services/notification_history_service.dart';
import '../services/pending_notification_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = true; // Start as loading until we get first auth state
  String? _error;
  bool _initialAuthCheckDone = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;

      // CRITICAL: Save to SharedPreferences for native notifications
      // This is required because native code reads from FlutterSharedPreferences
      if (user != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('currentUserId', user.uid);
          debugPrint(
            '✅ AuthProvider: Saved currentUserId to SharedPreferences',
          );
        } catch (e) {
          debugPrint('❌ AuthProvider: Failed to save currentUserId: $e');
        }
      }

      // First auth state received - stop loading
      if (!_initialAuthCheckDone) {
        _initialAuthCheckDone = true;
        _isLoading = false;
      }
      notifyListeners();
    });
  }

  /// Sign in with Google - OPTIMIZED
  /// Resets GoogleSignIn before login to ensure fresh session
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Reset GoogleSignIn to clear any stale tokens (SPEED OPTIMIZATION)
      await FirebaseService.resetGoogleSignIn();

      final userCredential = await FirebaseService.signInWithGoogle();

      // User cancelled the sign-in
      if (userCredential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = userCredential.user;

      // Save current user ID for data isolation
      final currentUserId = _user?.uid;
      if (currentUserId != null) {
        // CRITICAL FIX (Issue 3): Detect account switch and clear Firestore cache
        // This prevents data from previous user appearing for new user
        final previousUserId =
            HiveService.getUserData('currentUserId') as String?;
        if (previousUserId != null && previousUserId != currentUserId) {
          debugPrint(
            '⚠️ Account switch detected: $previousUserId → $currentUserId',
          );
          debugPrint('🔥 Clearing Firestore cache for account switch...');
          try {
            await FirebaseFirestore.instance.terminate();
            await FirebaseFirestore.instance.clearPersistence();
            debugPrint('✅ Firestore cache cleared for account switch');
          } catch (e) {
            debugPrint('⚠️ Failed to clear Firestore cache on switch: $e');
            // Continue with login - the new user's data will eventually sync
          }

          // Also clear Hive bills to prevent data leak
          await HiveService.clearAllData();
          debugPrint('✅ Hive data cleared for account switch');
        }

        // CRITICAL: Set current user in HiveService FIRST to invalidate cache
        // This prevents data from previous user being shown to new user
        HiveService.setCurrentUserId(currentUserId);
        debugPrint('✅ Set HiveService currentUserId for data isolation');

        final prefs = await SharedPreferences.getInstance();
        await HiveService.saveUserData('currentUserId', currentUserId);

        // CRITICAL: Also save to SharedPreferences for native Android code
        // The native AlarmReceiver reads from FlutterSharedPreferences
        await prefs.setString('currentUserId', currentUserId);
        debugPrint(
          '✅ Saved currentUserId to SharedPreferences for native notifications',
        );

        // Check if this is a new user (first time sign-in)
        final registrationKey = 'registrationDate_$currentUserId';
        final existingRegDate = HiveService.getUserData(registrationKey);
        if (existingRegDate == null) {
          // Save registration date for trial tracking (new user)
          await HiveService.saveUserData(
            registrationKey,
            DateTime.now().toIso8601String(),
          );
        }
      }

      // Start periodic sync
      SyncService.startPeriodicSync();

      // Process any pending notifications that were triggered while logged out
      // This ensures notifications from this user are added to history
      try {
        await PendingNotificationService.processPendingNotifications();
        debugPrint('✅ Processed pending notifications on login');
      } catch (e) {
        debugPrint('⚠️ Failed to process pending notifications: $e');
      }

      _isLoading = false;
      notifyListeners();

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _error = e.message ?? 'Google sign in failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Google sign in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // Check if there are unsynced bills
  int getUnsyncedBillsCount() {
    try {
      final unsyncedBills = HiveService.getBillsNeedingSync();
      return unsyncedBills.length;
    } catch (e) {
      return 0;
    }
  }

  // Sign out with automatic sync
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('\n🚪 ========== LOGOUT STARTED ==========');

      // Get current user ID before we clear anything
      final currentUserId = _user?.uid;
      debugPrint('👤 Logging out user: $currentUserId');

      // CRITICAL: Try to sync any unsynced bills BEFORE clearing data
      // Use timeout to prevent blocking logout on slow networks
      final unsyncedBills = HiveService.getBillsNeedingSync();
      if (unsyncedBills.isNotEmpty) {
        debugPrint(
          '⚠️ Found ${unsyncedBills.length} unsynced bills before logout',
        );
        debugPrint('📤 Attempting to sync to Firebase (5 second timeout)...');

        try {
          // Force sync with timeout - don't block logout on slow networks
          await SyncService.syncBills().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ Sync timeout - continuing with logout');
              debugPrint('📝 Unsynced bills will be synced on next login');
              // Don't throw - just continue with logout
            },
          );
          debugPrint('✅ Unsynced bills pushed to Firebase');
        } catch (e) {
          debugPrint('⚠️ Failed to sync bills before logout: $e');
          debugPrint('📝 Bills are saved locally, will sync on next login');
          // DON'T rethrow - allow logout to continue even if sync fails
          // Bills are still in Hive and marked needsSync=true
          // They will be synced when user logs back in
        }
      } else {
        debugPrint('✅ No unsynced bills to push');
      }

      // Stop sync
      SyncService.stopPeriodicSync();

      // CRITICAL: Clear currentUserId from SharedPreferences FIRST
      // This prevents native AlarmReceiver from showing notifications
      // for this user immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserId');
      debugPrint('✅ Cleared currentUserId from SharedPreferences');

      // Cancel all scheduled notifications for the current user
      debugPrint('🔕 Cancelling all scheduled notifications...');
      try {
        await NotificationService().cancelAllNotificationsForUser(
          currentUserId,
        );
        debugPrint('✅ All notifications cancelled for user');
      } catch (e) {
        debugPrint('⚠️ Failed to cancel notifications: $e');
        // Continue with logout even if notification cancellation fails
      }

      // Clear local data (bills, user preferences, notification tracking)
      debugPrint('🧹 Clearing local data...');
      await HiveService.clearAllData();

      // CRITICAL FIX: Clear Firestore offline cache to prevent data leak between users
      // This ensures cached bills from User A don't appear for User B
      debugPrint('🔥 Clearing Firestore offline cache...');
      try {
        await FirebaseFirestore.instance.clearPersistence();
        debugPrint('✅ Firestore offline cache cleared');
      } catch (e) {
        // clearPersistence() can fail if Firestore has pending operations
        // In that case, terminate and reinitialize
        debugPrint('⚠️ clearPersistence failed: $e, trying terminate...');
        try {
          await FirebaseFirestore.instance.terminate();
          await FirebaseFirestore.instance.clearPersistence();
          debugPrint('✅ Firestore terminated and cache cleared');
        } catch (e2) {
          debugPrint('⚠️ Failed to clear Firestore cache: $e2');
          // Continue with logout even if cache clearing fails
        }
      }

      // Clear notification history for current user only (preserve other users' history)
      // This ensures when user logs back in, they can see past notifications
      debugPrint('🗑️ Clearing notification tracking for current user...');
      await NotificationHistoryService.clearScheduledTrackingForUser(
        currentUserId,
      );

      // Clear session preferences but KEEP onboarding status per user
      // This ensures returning users don't see onboarding again
      await UserPreferencesService.clearSessionPreferences();

      // Sign out from Firebase and Google
      debugPrint('🔓 Signing out from Firebase...');
      await FirebaseService.signOutGoogle();

      // CRITICAL: Clear HiveService currentUserId to invalidate cache
      // This ensures next login starts with clean state
      HiveService.setCurrentUserId(null);
      debugPrint('✅ Cleared HiveService currentUserId');

      _user = null;
      _error = null;

      debugPrint('✅ Logout completed successfully');
      debugPrint('========================================\n');
    } catch (e) {
      _error = 'Sign out failed: $e';
      debugPrint('❌ Logout failed: $e');
      debugPrint('========================================\n');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }
}
