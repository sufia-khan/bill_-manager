import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_hive.dart';
import '../providers/notification_badge_provider.dart';
import '../providers/currency_provider.dart';
import '../services/offline_first_notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  // Blink animation state
  Set<String> _initiallyUnseenIds = {};
  bool _isBlinking = false;
  Timer? _blinkTimer;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();

    // Set up blink animation controller
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Capture initially unseen notifications before marking as seen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get unseen notification IDs before marking all as seen
      final notifications = OfflineFirstNotificationService.getNotifications();
      _initiallyUnseenIds = notifications
          .where((n) => !n.seen)
          .map((n) => n.id)
          .toSet();

      // Start blinking if there are unseen notifications
      if (_initiallyUnseenIds.isNotEmpty) {
        setState(() => _isBlinking = true);
        _blinkController.repeat(reverse: true);

        // Stop blinking after 2 seconds
        _blinkTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _isBlinking = false);
            _blinkController.stop();
            _blinkController.value = 1.0;
          }
        });
      }

      // Mark all as seen and refresh badge
      OfflineFirstNotificationService.markAllAsSeen();
      context.read<NotificationBadgeProvider>().forceRefresh();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _deleteSelectedNotifications() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Notifications?'),
        content: Text(
          'Are you sure you want to delete these $count selected notifications? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final idsToDelete = _selectedIds.toList();

      // Clear selection first UI-wise
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      await OfflineFirstNotificationService.deleteNotifications(idsToDelete);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count notifications deleted'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear notifications from service
      await OfflineFirstNotificationService.clearAllForUser();
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'OVERDUE':
        return Icons.warning_rounded;
      case 'DUE':
        return Icons.calendar_today_rounded;
      case 'PAID':
        return Icons.check_circle_rounded;
      case 'REMINDER':
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'OVERDUE':
        return const Color(0xFFDC2626); // Red
      case 'DUE':
        return const Color(0xFFF97316); // Orange
      case 'PAID':
        return const Color(0xFF059669); // Green
      case 'REMINDER':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();

    return ValueListenableBuilder(
      valueListenable: Hive.box<NotificationHive>('notifications').listenable(),
      builder: (context, Box<NotificationHive> box, _) {
        final notifications =
            OfflineFirstNotificationService.getNotifications();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: _isSelectionMode
                ? Text(
                    '${_selectedIds.length} Selected',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (notifications.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFECACA,
                            ), // Soft red background
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEF4444), // Red border
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${notifications.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626), // Dark red text
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: _isSelectionMode
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      });
                    },
                    icon: const Icon(Icons.close),
                  )
                : const BackButton(),
            actions: [
              if (_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteSelectedNotifications,
                  tooltip: 'Delete Selected',
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: _clearAllNotifications,
                  tooltip: 'Clear All',
                ),
            ],
          ),
          body: notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(
                      notification,
                      currencyProvider,
                    );
                  },
                ),
        );
      },
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Bill reminders will appear here',
              style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationHive notification,
    CurrencyProvider currencyProvider,
  ) {
    final color = _getColorForType(notification.type);
    final icon = _getIconForType(notification.type);
    final amount = notification.message.contains('\$')
        ? currencyProvider.formatCurrency(
            double.tryParse(
                  notification.message
                      .split('\$')[1]
                      .split(' ')[0]
                      .replaceAll(',', ''),
                ) ??
                0,
          )
        : '';

    final isSelected = _selectedIds.contains(notification.id);
    final shouldBlink =
        _isBlinking && _initiallyUnseenIds.contains(notification.id);

    // Wrap with AnimatedBuilder for blink effect
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        // Calculate blink opacity for background highlight
        final blinkOpacity = shouldBlink
            ? 0.15 +
                  (_blinkController.value * 0.15) // Pulse between 0.15 and 0.30
            : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: shouldBlink
                ? color.withOpacity(blinkOpacity)
                : (isSelected ? color.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withOpacity(0.1)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(notification.id);
                  });
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(notification.id);
                } else {
                  // Handle normal tap (maybe show details or mark as read)
                  // For now, it just doesn't do anything other than ripple
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
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title: "Water Bill Overdue"
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),

                          // Subtitle: "Occurrence 3 of 5"
                          if (notification.isRecurring &&
                              notification.recurringSequence != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Occurrence ${notification.recurringSequence}${notification.repeatCount != null ? ' of ${notification.repeatCount}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Message: "Drinking Water bill of $234 was due on 12 Nov"
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Timestamp - use scheduledFor to show when bill was actually due
                          Text(
                            timeago.format(notification.scheduledFor),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selection Checkbox with smooth animation
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: _isSelectionMode ? 32 : 0,
                        alignment: Alignment.centerRight,
                        child: _isSelectionMode
                            ? Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? color
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
