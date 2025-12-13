import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for generating and persisting a unique device identifier.
///
/// The device ID:
/// - Is generated once on first app launch
/// - Persists across app restarts and logout
/// - Is cleared on app reinstall (natural SharedPreferences behavior)
/// - Used to track which device created a bill for notification purposes
///
/// This enables device-local notifications in multi-device scenarios:
/// - Bill created on Device A → notification fires only on Device A
/// - Bill synced to Device B → no notification on Device B (just shows in UI)
class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static String? _cachedDeviceId;

  /// Get the unique device identifier.
  ///
  /// On first call, generates a new UUID and persists it.
  /// Subsequent calls return the cached value for performance.
  ///
  /// Thread-safe: Uses SharedPreferences which handles concurrency.
  static Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // First launch - generate new device ID
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
      print('📱 Generated new device ID: $deviceId');
    } else {
      print('📱 Loaded existing device ID: $deviceId');
    }

    // Cache for subsequent calls
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Clear the cached device ID (for testing purposes only).
  ///
  /// Note: This does NOT clear the persisted ID from SharedPreferences.
  /// Use only in test environments.
  static void clearCache() {
    _cachedDeviceId = null;
  }

  /// Check if this device created a specific bill.
  ///
  /// Returns true if the bill's createdDeviceId matches this device's ID.
  /// Returns false if bill has no device ID (legacy bill) or doesn't match.
  static Future<bool> isCreatedOnThisDevice(String? billDeviceId) async {
    if (billDeviceId == null) {
      // Legacy bill without device ID
      return false;
    }

    final currentDeviceId = await getDeviceId();
    return billDeviceId == currentDeviceId;
  }
}
