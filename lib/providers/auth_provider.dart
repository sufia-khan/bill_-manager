import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

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

  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseService.signUp(email, password);

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      _user = userCredential.user;
      _isLoading = false;
      notifyListeners();

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'weak-password':
          _error = 'The password is too weak';
          break;
        case 'email-already-in-use':
          _error = 'An account already exists for this email';
          break;
        case 'invalid-email':
          _error = 'Invalid email address';
          break;
        default:
          _error = e.message ?? 'Sign up failed';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseService.signIn(email, password);
      _user = userCredential.user;

      // Start sync after login
      await SyncService.initialSync();
      SyncService.startPeriodicSync();

      _isLoading = false;
      notifyListeners();

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'user-not-found':
          _error = 'No account found with this email';
          break;
        case 'wrong-password':
          _error = 'Incorrect password';
          break;
        case 'invalid-email':
          _error = 'Invalid email address';
          break;
        case 'user-disabled':
          _error = 'This account has been disabled';
          break;
        case 'invalid-credential':
          _error = 'Invalid email or password';
          break;
        default:
          _error = e.message ?? 'Sign in failed';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred';
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

      // Clear local data
      await HiveService.clearAllData();

      // Sign out from Firebase
      await FirebaseService.signOut();

      _user = null;
      _error = null;
    } catch (e) {
      _error = 'Sign out failed';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await FirebaseService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'user-not-found':
          _error = 'No account found with this email';
          break;
        case 'invalid-email':
          _error = 'Invalid email address';
          break;
        default:
          _error = e.message ?? 'Password reset failed';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
