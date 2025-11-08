import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_history.dart';
import '../services/notification_history_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationHistory> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _checkTriggeredNotifications();
    _loadNotifications();
    // Auto-mark all notifications as read when screen opens
    _markAllAsReadSilently();
  }

  Future<void> _markAllAsReadSilently() async {
    try {
      await NotificationHistoryService.markAllAsRead();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _checkTriggeredNotifications() async {
    try {
      // Check for any triggered notifications and add to history
      await NotificationHistoryService.checkAndAddTriggeredNotifications();
    } catch (e) {
      debugPrint('Error checking triggered notifications: $e');
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!loadMore) {
        // Reset for fresh load
        _currentPage = 0;
        _notifications.clear();
      } else {
        // Increment page for loading more
        _currentPage++;
      }

      final offset = _currentPage * _pageSize;
      final newNotifications = NotificationHistoryService.getNotifications(
        offset: offset,
        limit: _pageSize,
      );

      setState(() {
        if (newNotifications.isNotEmpty) {
          _notifications.addAll(newNotifications);
        }
        // Check if there are more notifications to load
        _hasMore = newNotifications.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: $e'),
            backgroundColor: Colors.red,
          ),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'en_short');
  }

  Widget _getIcon(NotificationHistory notification) {
    if (notification.billId != null) {
      if (notification.title.toLowerCase().contains('paid')) {
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF059669),
          size: 22,
        );
      } else if (notification.title.toLowerCase().contains('overdue')) {
        return const Icon(Icons.warning, color: Color(0xFFDC2626), size: 22);
      } else {
        return const Icon(
          Icons.access_time,
          color: Color(0xFFFF8C00),
          size: 22,
        );
      }
    }
    return const Icon(Icons.notifications, color: Color(0xFF3B82F6), size: 22);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = NotificationHistoryService.getUnreadCount();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
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
                color: Color(0xFFFF8C00),
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
        color: const Color(0xFFFF8C00),
        child: _notifications.isEmpty && !_isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 80,
                          color: Color(0xFFFF8C00),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'You\'ll see bill reminders and updates here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF8C00),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: () =>
                                    _loadNotifications(loadMore: true),
                                icon: const Icon(
                                  Icons.expand_more,
                                  color: Color(0xFFFF8C00),
                                ),
                                label: const Text(
                                  'Load More',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF8C00),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  backgroundColor: const Color(
                                    0xFFFF8C00,
                                  ).withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                      ),
                    );
                  }

                  final notification = _notifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteNotification(notification.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? Colors.white
                            : const Color(0xFFFF8C00).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: notification.isRead
                              ? Colors.grey.shade200
                              : const Color(0xFFFF8C00).withValues(alpha: 0.2),
                          width: notification.isRead ? 1 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () async {
                          if (!notification.isRead) {
                            await NotificationHistoryService.markAsRead(
                              notification.id,
                            );
                            _loadNotifications();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: _getIcon(notification),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: notification.isRead
                                                ? FontWeight.w500
                                                : FontWeight.w600,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                      if (!notification.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF8C00),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.body,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (notification.billTitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bill: ${notification.billTitle}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _getTimeAgo(notification.sentAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
