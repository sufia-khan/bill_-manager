import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_history.dart';
import '../providers/notification_badge_provider.dart';
import '../providers/currency_provider.dart';
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
  List<NotificationHistory> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // Refresh every 30 seconds to pick up new notifications
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    await PendingNotificationService.processPendingNotifications();
    if (mounted) {
      await _loadNotifications();
    }
  }

  Future<void> _initializeNotifications() async {
    await PendingNotificationService.processPendingNotifications();
    await _checkTriggeredNotifications();
    // Remove duplicates before loading
    final removedCount = await NotificationHistoryService.removeDuplicates();
    if (removedCount > 0) {
      debugPrint('🧹 Removed $removedCount duplicate notifications on init');
    }
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

      // Remove duplicates from the list (same billId on same day)
      final uniqueNotifications = _removeDuplicatesFromList(newNotifications);

      setState(() {
        if (uniqueNotifications.isNotEmpty) {
          _notifications.addAll(uniqueNotifications);
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

  // Remove duplicates from the loaded list (client-side dedup)
  List<NotificationHistory> _removeDuplicatesFromList(
    List<NotificationHistory> notifications,
  ) {
    final seen = <String>{};
    final unique = <NotificationHistory>[];

    for (final n in notifications) {
      // Create a unique key based on billId + day
      final dayKey = n.billId != null
          ? '${n.billId}_${n.sentAt.year}_${n.sentAt.month}_${n.sentAt.day}'
          : '${n.title}_${n.body}_${n.sentAt.year}_${n.sentAt.month}_${n.sentAt.day}';

      if (!seen.contains(dayKey)) {
        seen.add(dayKey);
        unique.add(n);
      }
    }

    return unique;
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_sweep,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clear All Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all notification history? This action cannot be undone.',
          style: TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('All notifications cleared'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationHistoryService.deleteNotification(id);
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
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
    if (title.contains('today')) return Icons.calendar_today_rounded;
    if (title.contains('tomorrow')) return Icons.event_rounded;
    if (title.contains('week')) return Icons.date_range_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _getColorForNotification(NotificationHistory notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('paid')) return const Color(0xFF059669);
    if (title.contains('overdue')) return const Color(0xFFDC2626);
    if (title.contains('today')) return const Color(0xFFF97316);
    if (title.contains('tomorrow')) return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  // Parse bill details from notification body
  Map<String, dynamic> _parseBillDetails(String body) {
    final result = <String, dynamic>{};
    try {
      // Pattern: "BillTitle - $Amount due to Vendor (X of Y)" or "(#X)"
      final dashIndex = body.indexOf(' - ');
      if (dashIndex > 0) {
        result['billName'] = body.substring(0, dashIndex).trim();
        String remaining = body.substring(dashIndex + 3);

        // Check for sequence pattern at the end
        final sequenceMatch = RegExp(
          r'\((\d+)\s*of\s*(\d+)\)$',
        ).firstMatch(remaining);
        final unlimitedMatch = RegExp(r'\(#(\d+)\)$').firstMatch(remaining);

        if (sequenceMatch != null) {
          result['currentSequence'] = int.parse(sequenceMatch.group(1)!);
          result['totalSequence'] = int.parse(sequenceMatch.group(2)!);
          remaining = remaining.substring(0, sequenceMatch.start).trim();
        } else if (unlimitedMatch != null) {
          result['currentSequence'] = int.parse(unlimitedMatch.group(1)!);
          result['isUnlimited'] = true;
          remaining = remaining.substring(0, unlimitedMatch.start).trim();
        }

        // Parse amount and vendor
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF374151),
                  size: 18,
                ),
              ),
            ),
            actions: [
              if (_notifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    onPressed: _clearAllNotifications,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                    tooltip: 'Clear All',
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
              title: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFF97316).withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          _notifications.isEmpty && !_isLoading
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == _notifications.length) {
                        return _hasMore
                            ? _buildLoadMoreButton()
                            : const SizedBox.shrink();
                      }
                      return _buildNotificationCard(_notifications[index]);
                    }, childCount: _notifications.length + 1),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF97316).withOpacity(0.1),
                  const Color(0xFFF97316).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Bill reminders and updates will appear here when scheduled',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoading
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _loadNotifications(loadMore: true),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.expand_more,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Load More',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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

  Widget _buildNotificationCard(NotificationHistory notification) {
    final isHighlighted = _highlightedId == notification.id;
    final color = _getColorForNotification(notification);
    final icon = _getIconForNotification(notification);
    final billDetails = _parseBillDetails(notification.body);
    final currencyProvider = context.watch<CurrencyProvider>();

    // Format amount with currency
    String formattedAmount = billDetails['amount'] ?? '';
    if (formattedAmount.isNotEmpty) {
      // Try to parse and reformat with user's currency
      final amountStr = formattedAmount.replaceAll(RegExp(r'[^\d.]'), '');
      final amount = double.tryParse(amountStr);
      if (amount != null) {
        formattedAmount = currencyProvider.formatCurrency(amount);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade300, Colors.red.shade500],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (direction) => _deleteNotification(notification.id),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? color : Colors.transparent,
              width: isHighlighted ? 2 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isHighlighted ? 16 : 10,
                offset: const Offset(0, 4),
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
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with gradient background
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with unread indicator
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withOpacity(0.7)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Amount, vendor, and sequence row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Amount badge
                              if (formattedAmount.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withOpacity(0.12),
                                        color.withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    formattedAmount,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              // Vendor
                              if (billDetails['vendor'] != null)
                                Text(
                                  'to ${billDetails['vendor']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              // Sequence badge for recurring bills
                              if (billDetails['currentSequence'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.repeat_rounded,
                                        size: 12,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        billDetails['isUnlimited'] == true
                                            ? '#${billDetails['currentSequence']}'
                                            : '${billDetails['currentSequence']} of ${billDetails['totalSequence']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Time row
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDateTime(notification.sentAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getTimeAgo(notification.sentAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
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
