import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_history.dart';
import '../providers/notification_badge_provider.dart';
import '../services/notification_history_service.dart';
import '../services/pending_notification_service.dart';
import '../services/hive_service.dart';

class NotificationScreen extends StatefulWidget {
  final String? highlightNotificationId;
  final bool openOverdueTab;

  const NotificationScreen({
    super.key,
    this.highlightNotificationId,
    this.openOverdueTab = false,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationHistory> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 10;
  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // Refresh every 10 seconds to pick up new notifications
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshNotifications();
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    // Process any new pending notifications from native layer
    await PendingNotificationService.processPendingNotifications();
    // Reload the list
    if (mounted) {
      await _loadNotifications();
    }
  }

  Future<void> _initializeNotifications() async {
    await PendingNotificationService.processPendingNotifications();
    await _checkTriggeredNotifications();
    await NotificationHistoryService.removeDuplicates();
    await _loadNotifications();
    await _markAllAsReadSilently();

    if (widget.highlightNotificationId != null) {
      _highlightedId = widget.highlightNotificationId;
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _highlightedId = null);
        }
      });
    }
  }

  Future<void> _markAllAsReadSilently() async {
    try {
      await NotificationHistoryService.markAllAsRead();
      if (mounted) {
        // Update badge provider to reflect read status
        context.read<NotificationBadgeProvider>().forceRefresh();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _checkTriggeredNotifications() async {
    try {
      final currentUserId = HiveService.getUserData('currentUserId') as String?;
      await NotificationHistoryService.checkAndAddTriggeredNotifications(
        currentUserId: currentUserId,
      );
    } catch (e) {
      debugPrint('Error checking triggered notifications: $e');
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (!loadMore) {
        _currentPage = 0;
        _notifications.clear();
      } else {
        _currentPage++;
      }

      final offset = _currentPage * _pageSize;
      final currentUserId = HiveService.getUserData('currentUserId') as String?;
      final newNotifications = NotificationHistoryService.getNotifications(
        offset: offset,
        limit: _pageSize,
        userId: currentUserId,
      );

      setState(() {
        if (newNotifications.isNotEmpty) {
          _notifications.addAll(newNotifications);
        }
        _hasMore = newNotifications.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notification history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationHistoryService.clearAll();
      _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationHistoryService.deleteNotification(id);
    _loadNotifications();
  }

  String _getTimeAgo(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'en_short');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    if (notificationDate == today) {
      return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    }
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  IconData _getIconForNotification(NotificationHistory notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('paid')) return Icons.check_circle_rounded;
    if (title.contains('overdue')) return Icons.warning_rounded;
    if (title.contains('today')) return Icons.today_rounded;
    if (title.contains('tomorrow')) return Icons.event_rounded;
    if (title.contains('week')) return Icons.date_range_rounded;
    return Icons.notifications_rounded;
  }

  Color _getColorForNotification(NotificationHistory notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('paid')) return const Color(0xFF059669);
    if (title.contains('overdue')) return const Color(0xFFDC2626);
    if (title.contains('today')) return const Color(0xFFF97316);
    return const Color(0xFF3B82F6);
  }

  Map<String, String> _parseBillDetails(String body) {
    final result = <String, String>{};
    try {
      final dashIndex = body.indexOf(' - ');
      if (dashIndex > 0) {
        result['billName'] = body.substring(0, dashIndex).trim();
        final remaining = body.substring(dashIndex + 3);
        final dueToIndex = remaining.indexOf(' due to ');
        if (dueToIndex > 0) {
          result['amount'] = remaining.substring(0, dueToIndex).trim();
          result['vendor'] = remaining.substring(dueToIndex + 8).trim();
        } else {
          result['amount'] = remaining.trim();
        }
      } else {
        result['billName'] = body;
      }
    } catch (e) {
      result['billName'] = body;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = HiveService.getUserData('currentUserId') as String?;
    final unreadCount = NotificationHistoryService.getUnreadCount(
      userId: currentUserId,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF374151),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF97316),
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _clearAllNotifications,
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: Colors.grey.shade600,
                size: 22,
              ),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(),
        color: const Color(0xFFF97316),
        child: _notifications.isEmpty && !_isLoading
            ? _buildEmptyState()
            : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 64,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Bill reminders and updates will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _notifications.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _notifications.length) {
          return _buildLoadMoreButton();
        }
        return _buildNotificationCard(_notifications[index]);
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              )
            : TextButton.icon(
                onPressed: () => _loadNotifications(loadMore: true),
                icon: const Icon(Icons.expand_more, color: Color(0xFFF97316)),
                label: const Text(
                  'Load More',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF97316),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: const Color(
                    0xFFF97316,
                  ).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationHistory notification) {
    final isHighlighted = _highlightedId == notification.id;
    final color = _getColorForNotification(notification);
    final icon = _getIconForNotification(notification);
    final billDetails = _parseBillDetails(notification.body);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        onDismissed: (direction) => _deleteNotification(notification.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isHighlighted ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? color : Colors.grey.shade200,
              width: isHighlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isHighlighted ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (!notification.isRead) {
                  await NotificationHistoryService.markAsRead(notification.id);
                  _loadNotifications();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with unread indicator
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Bill name
                          if (billDetails['billName'] != null)
                            Text(
                              billDetails['billName']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          const SizedBox(height: 4),
                          // Amount and vendor
                          Row(
                            children: [
                              if (billDetails['amount'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    billDetails['amount']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ),
                              if (billDetails['vendor'] != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'to ${billDetails['vendor']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Time
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(notification.sentAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${_getTimeAgo(notification.sentAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
