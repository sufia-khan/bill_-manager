import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/user_preferences_service.dart';
import '../services/pending_notification_service.dart';
import '../services/account_isolation_service.dart';

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

  /// Sign in with Google - with complete data isolation
  /// Uses AccountIsolationService for clean state on login
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Reset GoogleSignIn to clear any stale tokens
      await FirebaseService.resetGoogleSignIn();

      final userCredential = await FirebaseService.signInWithGoogle();

      // User cancelled the sign-in
      if (userCredential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = userCredential.user;

      // CRITICAL: Use centralized cleanup for clean login state
      if (_user != null) {
        await AccountIsolationService.cleanLogin(_user!);

        // Check if this is a new user (first time sign-in)
        final registrationKey = 'registrationDate_${_user!.uid}';
        final existingRegDate = HiveService.getUserData(registrationKey);
        if (existingRegDate == null) {
          // Save registration date for trial tracking (new user)
          await HiveService.saveUserData(
            registrationKey,
            DateTime.now().toIso8601String(),
          );
        }
      }

      // Process any pending notifications that were triggered while logged out
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

  // Sign out with complete data isolation cleanup
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('\n🚪 ========== LOGOUT STARTED ==========');

      // Get current user ID before we clear anything
      final currentUserId = _user?.uid;
      debugPrint('👤 Logging out user: $currentUserId');

      // Use centralized cleanup service for complete data isolation
      await AccountIsolationService.cleanLogout();

      // Clear session preferences but KEEP onboarding status per user
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
