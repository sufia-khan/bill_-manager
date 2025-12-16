import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Service for managing app lock functionality
/// Supports both biometric authentication and PIN code
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Preference keys
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyUseBiometrics = 'app_lock_use_biometrics';
  static const String _keyLockPin = 'app_lock_pin';
  static const String _keyLockTimeout = 'app_lock_timeout';
  static const String _keyLastBackgroundTime = 'app_lock_last_background';

  // Default timeout in seconds (30 seconds)
  static const int defaultTimeout = 30;

  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Get human-readable biometric type name
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometrics';
  }

  /// Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock BillMinder',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Biometric authentication error: ${e.message}');
      return false;
    }
  }

  /// Verify PIN code
  Future<bool> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_keyLockPin);
    if (storedPin == null) return false;

    // Simple hash comparison (in production, use proper encryption)
    final enteredHash = _hashPin(enteredPin);
    return storedPin == enteredHash;
  }

  /// Set new PIN code
  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final hashedPin = _hashPin(pin);
    await prefs.setString(_keyLockPin, hashedPin);
    return true;
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLockPin) != null;
  }

  /// Remove PIN
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLockPin);
  }

  /// Simple hash function for PIN (use proper encryption in production)
  String _hashPin(String pin) {
    // Simple base64 encoding - in production use bcrypt or similar
    final bytes = utf8.encode('billminder_salt_$pin');
    return base64.encode(bytes);
  }

  // ============ Settings Management ============

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAppLockEnabled) ?? false;
  }

  /// Enable or disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, enabled);
  }

  /// Check if biometrics should be used
  Future<bool> shouldUseBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseBiometrics) ?? true;
  }

  /// Set whether to use biometrics
  Future<void> setUseBiometrics(bool use) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseBiometrics, use);
  }

  /// Get lock timeout in seconds
  Future<int> getLockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLockTimeout) ?? defaultTimeout;
  }

  /// Set lock timeout in seconds
  Future<void> setLockTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLockTimeout, seconds);
  }

  // ============ Lock State Management ============

  /// Record when app went to background
  Future<void> recordBackgroundTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyLastBackgroundTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Check if app should be locked based on timeout
  Future<bool> shouldShowLockScreen() async {
    final isEnabled = await isAppLockEnabled();
    if (!isEnabled) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastBackgroundTime = prefs.getInt(_keyLastBackgroundTime);

    if (lastBackgroundTime == null) return false;

    final backgroundDuration =
        DateTime.now().millisecondsSinceEpoch - lastBackgroundTime;
    final timeout = await getLockTimeout();

    // Convert timeout from seconds to milliseconds
    return backgroundDuration > (timeout * 1000);
  }

  /// Clear background time (called after successful unlock)
  Future<void> clearBackgroundTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastBackgroundTime);
  }

  /// Complete authentication flow
  /// Returns true if authenticated successfully
  Future<bool> authenticate() async {
    final useBiometrics = await shouldUseBiometrics();
    final biometricAvailable = await isBiometricAvailable();

    if (useBiometrics && biometricAvailable) {
      final success = await authenticateWithBiometrics();
      if (success) {
        await clearBackgroundTime();
        return true;
      }
    }

    // Fall through to PIN if biometrics failed or not available
    return false; // Caller should show PIN screen
  }
}
