import 'package:hive_flutter/hive_flutter.dart';

class UserPreferencesService {
  static const String _boxName = 'userPreferences';
  static const String _onboardingPrefix = 'hasSeenOnboarding_';
  // Legacy key for backwards compatibility
  static const String _legacyOnboardingKey = 'hasSeenOnboarding';

  static Box? _box;

  /// Initialize the user preferences service
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    print(
      '📦 UserPreferencesService initialized. Box keys: ${_box?.keys.toList()}',
    );
  }

  /// Check if user has seen the onboarding screen (per-user tracking)
  /// [userId] - The Firebase user ID to check onboarding status for
  static bool hasSeenOnboarding({String? userId}) {
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
    if (userId == null) {
      // Fallback to legacy key
      await _box?.put(_legacyOnboardingKey, true);
      print('✅ setOnboardingSeen (legacy): saved to $_legacyOnboardingKey');
      return;
    }
    final key = '$_onboardingPrefix$userId';
    await _box?.put(key, true);
    print('✅ setOnboardingSeen: saved to $key, box: ${_box != null}');
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
