import 'dart:async';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_history.dart';
import '../providers/notification_badge_provider.dart';
import '../providers/currency_provider.dart';
import '../services/notification_history_service.dart';
import '../services/pending_notification_service.dart';

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
  String? _highlightedId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await PendingNotificationService.processPendingNotifications();
    await _checkTriggeredNotifications();
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
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      await NotificationHistoryService.markAllAsRead(userId: currentUserId);
      if (mounted) {
        context.read<NotificationBadgeProvider>().forceRefresh();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _checkTriggeredNotifications() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      await NotificationHistoryService.checkAndAddTriggeredNotifications(
        currentUserId: currentUserId,
      );
    } catch (e) {
      debugPrint('Error checking triggered notifications: $e');
    }
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
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      await NotificationHistoryService.clearAll(userId: currentUserId);
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    await NotificationHistoryService.deleteNotification(
      id,
      userId: currentUserId,
    );
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
    // Use FirebaseAuth for the source of truth for Firestore permissions
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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

          // Content using Firestore Stream
          if (currentUserId == null)
            SliverFillRemaining(child: _buildEmptyState())
          else
            StreamBuilder<QuerySnapshot>(
              stream:
                  NotificationHistoryService.getFirestoreNotificationsStream(
                    currentUserId,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error.toString();
                  final isPermissionError =
                      error.contains('permission-denied') ||
                      error.contains('PERMISSION_DENIED');

                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade400,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isPermissionError
                                  ? 'Access Denied'
                                  : 'Something went wrong',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPermissionError
                                  ? 'Please try logging out and logging back in to refresh your session.\nIf the issue persists, ensure Firestore rules are deployed.'
                                  : 'Error: $error',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                            if (isPermissionError) ...[
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  }
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Log Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFF97316),
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(child: _buildEmptyState());
                }

                // Convert snapshots to NotificationHistory objects
                final notifications = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Handle both 'timestamp' (int/long) and Firestore Timestamp
                  final rawTimestamp = data['timestamp'];
                  DateTime sentAt;
                  if (rawTimestamp is Timestamp) {
                    sentAt = rawTimestamp.toDate();
                  } else if (rawTimestamp is int) {
                    sentAt = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
                  } else {
                    sentAt = DateTime.now(); // Fallback
                  }

                  return NotificationHistory(
                    id: doc.id,
                    title: data['title'] as String,
                    body: data['body'] as String,
                    billId: data['billId'] as String?,
                    billTitle: data['billTitle'] as String?,
                    isRead:
                        (data['status'] == 'read') || (data['isRead'] == true),
                    sentAt: sentAt,
                    createdAt: sentAt,
                    userId: currentUserId,
                  );
                }).toList();

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildNotificationCard(notifications[index]);
                    }, childCount: notifications.length),
                  ),
                );
              },
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
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  await NotificationHistoryService.markAsRead(
                    notification.id,
                    userId: currentUserId,
                  );
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
                                    ),
                                  ),
                                  child: Text(
                                    billDetails['isUnlimited'] == true
                                        ? '#${billDetails['currentSequence']}'
                                        : '${billDetails['currentSequence']} of ${billDetails['totalSequence']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Time
                          Text(
                            timeago.format(
                              notification.sentAt,
                              locale: 'en_short',
                            ),
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
          ),
        ),
      ),
    );
  }
}
