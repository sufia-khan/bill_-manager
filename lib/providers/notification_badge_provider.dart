import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/offline_first_notification_service.dart';
import '../services/pending_notification_service.dart';
import '../services/firebase_service.dart';

/// Provider to manage notification badge count with real-time updates
class NotificationBadgeProvider extends ChangeNotifier {
  int _unreadCount = 0;
  Timer? _refreshTimer;
  bool _isProcessing = false;

  int get unreadCount => _unreadCount;

  NotificationBadgeProvider() {
    _startPeriodicRefresh();
    refreshCount();
  }

  /// Start periodic refresh to check for new notifications
  void _startPeriodicRefresh() {
    // Check every 3 seconds for new notifications (faster for real-time updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _processAndRefresh();
    });
  }

  /// Process pending notifications from native layer and refresh count
  Future<void> _processAndRefresh() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Process any pending notifications from native AlarmReceiver
      await PendingNotificationService.processPendingNotifications();

      // Then refresh the count
      refreshCount();
    } catch (e) {
      debugPrint('Error processing pending notifications: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Refresh the unread count - use OfflineFirstNotificationService
  void refreshCount() {
    final currentUserId = FirebaseService.currentUserId;
    final newCount = OfflineFirstNotificationService.getUnreadCount(
      userId: currentUserId,
    );

    if (newCount != _unreadCount) {
      _unreadCount = newCount;
      notifyListeners();
    }
  }

  /// Mark all as read and refresh
  Future<void> markAllAsRead() async {
    await OfflineFirstNotificationService.markAllAsSeen();
    _unreadCount = 0;
    notifyListeners();
  }

  /// Force refresh (call after adding new notification)
  Future<void> forceRefresh() async {
    await _processAndRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
