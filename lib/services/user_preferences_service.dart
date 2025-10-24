import 'package:hive_flutter/hive_flutter.dart';

class UserPreferencesService {
  static const String _boxName = 'userPreferences';
  static const String _hasSeenOnboardingKey = 'hasSeenOnboarding';

  static Box? _box;

  /// Initialize the user preferences service
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Check if user has seen the onboarding screen
  static bool hasSeenOnboarding() {
    return _box?.get(_hasSeenOnboardingKey, defaultValue: false) ?? false;
  }

  /// Mark onboarding as seen
  static Future<void> setOnboardingSeen() async {
    await _box?.put(_hasSeenOnboardingKey, true);
  }

  /// Reset onboarding status (useful for testing or user logout)
  static Future<void> resetOnboarding() async {
    await _box?.put(_hasSeenOnboardingKey, false);
  }

  /// Clear all user preferences (useful for logout)
  static Future<void> clearAll() async {
    await _box?.clear();
  }
}
