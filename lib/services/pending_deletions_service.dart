import 'package:hive_flutter/hive_flutter.dart';

/// Service to track pending bill deletions that must survive logout.
///
/// When a user deletes a bill offline and logs out before syncing,
/// this service ensures the deletion is preserved and applied on next login.
///
/// Deletions are stored per-user to maintain account isolation.
class PendingDeletionsService {
  static const String _boxName = 'pending_deletions';
  static Box<List<String>>? _box;

  /// Initialize the service - call during app startup
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    try {
      _box = await Hive.openBox<List<String>>(_boxName);
      print('✅ PendingDeletionsService initialized');
    } catch (e) {
      print('⚠️ Error initializing PendingDeletionsService: $e');
      // Try to recover by deleting and recreating
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<List<String>>(_boxName);
        print('✅ PendingDeletionsService recovered');
      } catch (e2) {
        print('❌ Failed to recover PendingDeletionsService: $e2');
      }
    }
  }

  /// Get the box, initializing if needed
  static Future<Box<List<String>>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  /// Add a pending deletion for a user
  /// This will survive logout and be processed on next login
  static Future<void> addPendingDeletion(String userId, String billId) async {
    if (userId.isEmpty || billId.isEmpty) return;

    final box = await _getBox();
    final existing = box.get(userId)?.toList() ?? [];

    if (!existing.contains(billId)) {
      existing.add(billId);
      await box.put(userId, existing);
      print(
        '📌 PendingDeletions: Added $billId for user ${userId.substring(0, 8)}...',
      );
    }
  }

  /// Add multiple pending deletions at once (for recurring bill series)
  static Future<void> addPendingDeletions(
    String userId,
    List<String> billIds,
  ) async {
    if (userId.isEmpty || billIds.isEmpty) return;

    final box = await _getBox();
    final existing = box.get(userId)?.toList() ?? [];

    int added = 0;
    for (final billId in billIds) {
      if (!existing.contains(billId)) {
        existing.add(billId);
        added++;
      }
    }

    if (added > 0) {
      await box.put(userId, existing);
      print(
        '📌 PendingDeletions: Added $added bills for user ${userId.substring(0, 8)}...',
      );
    }
  }

  /// Get all pending deletions for a user
  static Future<Set<String>> getPendingDeletions(String userId) async {
    if (userId.isEmpty) return {};

    final box = await _getBox();
    final deletions = box.get(userId) ?? [];
    return deletions.toSet();
  }

  /// Get pending deletions synchronously (use only if box is already open)
  static Set<String> getPendingDeletionsSync(String userId) {
    if (userId.isEmpty || _box == null || !_box!.isOpen) return {};

    final deletions = _box!.get(userId) ?? [];
    return deletions.toSet();
  }

  /// Remove a pending deletion after successful sync to Firestore
  static Future<void> removePendingDeletion(
    String userId,
    String billId,
  ) async {
    if (userId.isEmpty || billId.isEmpty) return;

    final box = await _getBox();
    final existing = box.get(userId)?.toList() ?? [];

    if (existing.remove(billId)) {
      await box.put(userId, existing);
      print(
        '✓ PendingDeletions: Removed $billId for user ${userId.substring(0, 8)}...',
      );
    }
  }

  /// Remove multiple pending deletions at once
  static Future<void> removePendingDeletions(
    String userId,
    List<String> billIds,
  ) async {
    if (userId.isEmpty || billIds.isEmpty) return;

    final box = await _getBox();
    final existing = box.get(userId)?.toList() ?? [];

    int removed = 0;
    for (final billId in billIds) {
      if (existing.remove(billId)) {
        removed++;
      }
    }

    if (removed > 0) {
      await box.put(userId, existing);
      print(
        '✓ PendingDeletions: Removed $removed bills for user ${userId.substring(0, 8)}...',
      );
    }
  }

  /// Clear all pending deletions for a user (after full successful sync)
  static Future<void> clearAllForUser(String userId) async {
    if (userId.isEmpty) return;

    final box = await _getBox();
    final existing = box.get(userId);

    if (existing != null && existing.isNotEmpty) {
      await box.delete(userId);
      print(
        '🧹 PendingDeletions: Cleared ${existing.length} deletions for user ${userId.substring(0, 8)}...',
      );
    }
  }

  /// Check if a bill is pending deletion for a user
  static Future<bool> isPendingDeletion(String userId, String billId) async {
    if (userId.isEmpty || billId.isEmpty) return false;

    final deletions = await getPendingDeletions(userId);
    return deletions.contains(billId);
  }

  /// Get count of pending deletions for a user
  static Future<int> getPendingDeletionsCount(String userId) async {
    final deletions = await getPendingDeletions(userId);
    return deletions.length;
  }

  /// Debug: Print all pending deletions
  static Future<void> debugPrint() async {
    final box = await _getBox();
    print('📋 PendingDeletions Debug:');
    for (final key in box.keys) {
      final deletions = box.get(key);
      print('   User $key: ${deletions?.length ?? 0} pending deletions');
      if (deletions != null) {
        for (final billId in deletions) {
          print('      - $billId');
        }
      }
    }
  }
}
