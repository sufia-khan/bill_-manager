import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../services/user_preferences_service.dart';

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

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Stop sync
      SyncService.stopPeriodicSync();

      // Note: Background task cancellation removed (workmanager not used)

      // Clear local data
      await HiveService.clearAllData();

      // Clear session preferences but KEEP onboarding status per user
      // This ensures returning users don't see onboarding again
      await UserPreferencesService.clearSessionPreferences();

      // Sign out from Firebase and Google
      await FirebaseService.signOutGoogle();

      _user = null;
      _error = null;
    } catch (e) {
      _error = 'Sign out failed';
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
}
