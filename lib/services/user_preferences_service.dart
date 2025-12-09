import 'package:hive_flutter/hive_flutter.dart';

class UserPreferencesService {
  static const String _boxName = 'userPreferences';
  static const String _onboardingPrefix = 'hasSeenOnboarding_';
  // Legacy key for backwards compatibility
  static const String _legacyOnboardingKey = 'hasSeenOnboarding';

  static Box? _box;
  static bool _isInitialized = false;

  /// Initialize the user preferences service
  static Future<void> init() async {
    if (_isInitialized && _box != null && _box!.isOpen) {
      return; // Already initialized
    }

    try {
      // Check if box is already open
      if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box(_boxName);
      } else {
        _box = await Hive.openBox(_boxName);
      }
      _isInitialized = true;
      print(
        '📦 UserPreferencesService initialized. Box keys: ${_box?.keys.toList()}',
      );
    } catch (e) {
      print('❌ UserPreferencesService init error: $e');
      _isInitialized = false;
    }
  }

  /// Ensure the service is initialized before use
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized || _box == null || !_box!.isOpen) {
      await init();
    }
  }

  /// Check if user has seen the onboarding screen (per-user tracking)
  /// [userId] - The Firebase user ID to check onboarding status for
  static bool hasSeenOnboarding({String? userId}) {
    // Safety check - if box is not ready, don't show onboarding yet
    // This prevents the race condition where box is null
    if (_box == null || !_box!.isOpen) {
      print(
        '⚠️ hasSeenOnboarding: Box not ready, returning true to prevent showing',
      );
      return true; // Return true to prevent showing onboarding when box isn't ready
    }

    if (userId == null) {
      // Fallback to legacy check if no userId provided
      final result =
          _box?.get(_legacyOnboardingKey, defaultValue: false) ?? false;
      print('🔍 hasSeenOnboarding (legacy): $result, box: ${_box != null}');
      return result;
    }

    // First check user-specific key
    final key = '$_onboardingPrefix$userId';
    final userResult = _box?.get(key, defaultValue: false) ?? false;

    // Also check legacy key for backwards compatibility (old installs)
    final legacyResult =
        _box?.get(_legacyOnboardingKey, defaultValue: false) ?? false;

    // User has seen onboarding if EITHER key is true
    final result = userResult || legacyResult;
    print(
      '🔍 hasSeenOnboarding (userId: $userId): userKey=$userResult, legacy=$legacyResult, final=$result, box: ${_box != null}',
    );
    return result;
  }

  /// Mark onboarding as seen for a specific user
  /// [userId] - The Firebase user ID to mark onboarding as seen for
  static Future<void> setOnboardingSeen({String? userId}) async {
    // Ensure box is initialized before saving
    await _ensureInitialized();

    if (_box == null || !_box!.isOpen) {
      print('❌ setOnboardingSeen: Box not available, cannot save');
      return;
    }

    if (userId == null) {
      // Fallback to legacy key
      await _box?.put(_legacyOnboardingKey, true);
      print('✅ setOnboardingSeen (legacy): saved to $_legacyOnboardingKey');
      return;
    }
    final key = '$_onboardingPrefix$userId';
    await _box?.put(key, true);
    // Also set legacy key for extra safety
    await _box?.put(_legacyOnboardingKey, true);
    print(
      '✅ setOnboardingSeen: saved to $key and legacy key, box: ${_box != null}',
    );
  }

  /// Reset onboarding status for a specific user (useful for testing)
  /// [userId] - The Firebase user ID to reset onboarding status for
  static Future<void> resetOnboarding({String? userId}) async {
    if (userId == null) {
      await _box?.put(_legacyOnboardingKey, false);
      return;
    }
    final key = '$_onboardingPrefix$userId';
    await _box?.put(key, false);
  }

  /// Get auto-delete archived bills preference (default: true)
  static bool getAutoDeleteArchivedBills() {
    return _box?.get('autoDeleteArchivedBills', defaultValue: true) ?? true;
  }

  /// Set auto-delete archived bills preference
  static Future<void> setAutoDeleteArchivedBills(bool enabled) async {
    await _box?.put('autoDeleteArchivedBills', enabled);
    print('💾 Auto-delete archived bills: $enabled');
  }

  /// Get auto-archive paid bills preference (default: true for Pro users)
  static bool getAutoArchivePaidBills() {
    return _box?.get('autoArchivePaidBills', defaultValue: true) ?? true;
  }

  /// Set auto-archive paid bills preference
  static Future<void> setAutoArchivePaidBills(bool enabled) async {
    await _box?.put('autoArchivePaidBills', enabled);
    print('💾 Auto-archive paid bills: $enabled');
  }

  /// Get default reminder time (default: 09:00)
  static String getDefaultReminderTime() {
    return _box?.get('defaultReminderTime', defaultValue: '09:00') ?? '09:00';
  }

  /// Set default reminder time (format: HH:mm in 24-hour format)
  static Future<void> setDefaultReminderTime(String time) async {
    await _box?.put('defaultReminderTime', time);
    print('💾 Default reminder time: $time');
  }

  /// Clear session-specific preferences (NOT onboarding status)
  /// Call this on logout to reset session data while preserving onboarding history
  static Future<void> clearSessionPreferences() async {
    // Don't clear onboarding status - it should persist per user
    // Only clear other session-specific preferences if any are added in future
  }

  /// Clear ALL user preferences including onboarding (use with caution)
  /// This should only be used for complete app reset, not regular logout
  static Future<void> clearAll() async {
    await _box?.clear();
  }
}
