import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../services/user_preferences_service.dart';
import '../services/notification_service.dart';
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
          print(
            '✅ AuthProvider: Saved currentUserId to SharedPreferences for native notifications',
          );
        } catch (e) {
          print('❌ AuthProvider: Failed to save currentUserId: $e');
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
        final prefs = await SharedPreferences.getInstance();
        await HiveService.saveUserData('currentUserId', currentUserId);

        // CRITICAL: Also save to SharedPreferences for native Android code
        // The native AlarmReceiver reads from FlutterSharedPreferences
        await prefs.setString('currentUserId', currentUserId);
        print(
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
        print('✅ Processed pending notifications on login');
      } catch (e) {
        print('⚠️ Failed to process pending notifications: $e');
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

      // CRITICAL: Clear currentUserId from SharedPreferences
      // This prevents notifications from other accounts showing on device
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserId');
      print('✅ Cleared currentUserId from SharedPreferences');

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

  // Refresh user data
  Future<void> refreshUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  // Delete account permanently - FAST but COMPLETE deletion
  Future<void> deleteAccount() async {
    final userId = FirebaseService.currentUserId;
    final authUser = FirebaseAuth.instance.currentUser;

    if (userId == null) throw Exception('No user logged in');
    if (authUser == null) throw Exception('No authenticated user');

    debugPrint('[Delete] Starting FAST account deletion for: $userId');
    SyncService.stopPeriodicSync();

    // STEP 1: Delete Firestore data with AGGRESSIVE timeout (2 seconds max)
    try {
      await FirebaseService.deleteAllUserData(
        userId,
      ).timeout(const Duration(seconds: 2));
      debugPrint('[Delete] ✅ Firestore deleted');
    } catch (e) {
      debugPrint('[Delete] ⚠️ Firestore timeout/error: $e');
      // Continue anyway
    }

    // STEP 2: Delete Auth user (1 second max, no reauth)
    try {
      await authUser.delete().timeout(const Duration(seconds: 1));
      debugPrint('[Delete] ✅ Auth deleted');
    } catch (e) {
      debugPrint('[Delete] ⚠️ Auth error, signing out: $e');
      await FirebaseAuth.instance.signOut();
    }

    // STEP 3: Clear local data (instant)
    await Future.wait([
      HiveService.clearAllData(),
      UserPreferencesService.clearAll(),
      NotificationService().cancelAllNotifications(),
      SharedPreferences.getInstance().then((p) => p.clear()),
    ]);

    // STEP 4: Update state
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();

    debugPrint('[Delete] ✅ Deletion completed');
  }
}
