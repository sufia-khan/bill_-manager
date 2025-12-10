import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // CRITICAL: Sync any unsynced bills BEFORE clearing data
      final unsyncedBills = HiveService.getBillsNeedingSync();
      if (unsyncedBills.isNotEmpty) {
        debugPrint(
          '⚠️ Found ${unsyncedBills.length} unsynced bills before logout',
        );
        debugPrint('📤 Syncing to Firebase before clearing...');

        try {
          // Force sync now
          await SyncService.syncBills();
          debugPrint('✅ Unsynced bills pushed to Firebase');
        } catch (e) {
          debugPrint('❌ Failed to sync bills before logout: $e');
          debugPrint('⚠️ Bills will be lost! Consider canceling logout.');
          // Rethrow to let UI handle the error
          rethrow;
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
