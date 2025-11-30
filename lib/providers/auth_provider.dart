import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../services/user_preferences_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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
        await HiveService.saveUserData('currentUserId', currentUserId);

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
      print('\n🚪 ========== LOGOUT STARTED ==========');

      // CRITICAL: Sync any unsynced bills BEFORE clearing data
      final unsyncedBills = HiveService.getBillsNeedingSync();
      if (unsyncedBills.isNotEmpty) {
        print('⚠️ Found ${unsyncedBills.length} unsynced bills before logout');
        print('📤 Syncing to Firebase before clearing...');

        try {
          // Force sync now
          await SyncService.syncBills();
          print('✅ Unsynced bills pushed to Firebase');
        } catch (e) {
          print('❌ Failed to sync bills before logout: $e');
          print('⚠️ Bills will be lost! Consider canceling logout.');
          // Rethrow to let UI handle the error
          rethrow;
        }
      } else {
        print('✅ No unsynced bills to push');
      }

      // Stop sync
      SyncService.stopPeriodicSync();

      // Note: Background task cancellation removed (workmanager not used)

      // Cancel all scheduled notifications for the current user
      print('🔕 Cancelling all scheduled notifications...');
      try {
        await NotificationService().cancelAllNotifications();
        print('✅ All notifications cancelled');
      } catch (e) {
        print('⚠️ Failed to cancel notifications: $e');
        // Continue with logout even if notification cancellation fails
      }

      // Clear local data
      print('🧹 Clearing local data...');
      await HiveService.clearAllData();

      // Clear session preferences but KEEP onboarding status per user
      // This ensures returning users don't see onboarding again
      await UserPreferencesService.clearSessionPreferences();

      // Sign out from Firebase and Google
      print('🔓 Signing out from Firebase...');
      await FirebaseService.signOutGoogle();

      _user = null;
      _error = null;

      print('✅ Logout completed successfully');
      print('========================================\n');
    } catch (e) {
      _error = 'Sign out failed: $e';
      print('❌ Logout failed: $e');
      print('========================================\n');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
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

  // Delete account permanently (ULTRA-FAST)
  Future<void> deleteAccount() async {
    try {
      print('\n🗑️ ========== ULTRA-FAST ACCOUNT DELETION ==========');

      // Stop sync service immediately
      SyncService.stopPeriodicSync();

      // Cancel all scheduled notifications
      print('🔕 Cancelling all scheduled notifications...');
      try {
        await NotificationService().cancelAllNotifications();
        print('✅ All notifications cancelled');
      } catch (e) {
        print('⚠️ Failed to cancel notifications: $e');
        // Continue with account deletion even if notification cancellation fails
      }

      // Update state immediately so UI can proceed (don't wait for anything)
      _user = null;
      _error = null;
      _isLoading = false;
      notifyListeners();

      // Delete from Firestore and Firebase Auth in background
      print('🔥 Deleting cloud data in background...');
      FirebaseService.deleteUserAccount()
          .then((_) {
            print('✅ Cloud data deleted');
          })
          .catchError((e) {
            print('⚠️ Cloud deletion error (non-critical): $e');
          });

      // Clear local data in background (don't wait for this)
      print('🧹 Clearing local data in background...');
      Future.wait([
            HiveService.clearAllData(),
            UserPreferencesService.clearAll(),
          ])
          .then((_) {
            print('✅ Local data cleared');
            print('🎉 Account deleted!');
            print('========================================\n');
          })
          .catchError((e) {
            print('⚠️ Local cleanup error (non-critical): $e');
            print('========================================\n');
          });
    } catch (e, stackTrace) {
      _error = 'Account deletion failed: $e';
      print('❌ Failed: $e');
      print('Stack: $stackTrace');
      print('========================================\n');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
