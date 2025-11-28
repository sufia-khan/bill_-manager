import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/bill_hive.dart';
import '../providers/bill_provider.dart';
import '../utils/formatters.dart';
import '../screens/add_bill_screen.dart';

class BillDetailsBottomSheet extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onMarkPaid;

  const BillDetailsBottomSheet({
    super.key,
    required this.bill,
    this.onMarkPaid,
  });

  String _formatNotificationTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final displayMinute = minute.toString().padLeft(2, '0');
        return '$displayHour:$displayMinute $period';
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return time;
  }

  String _getCategoryEmoji() {
    final categoryEmojis = {
      'Subscriptions': '📋',
      'Rent': '🏠',
      'Utilities': '💡',
      'Electricity': '⚡',
      'Water': '💧',
      'Gas': '🔥',
      'Internet': '🌐',
      'Phone': '📱',
      'Streaming': '📺',
      'Groceries': '🛒',
      'Transport': '🚌',
      'Fuel': '⛽',
      'Insurance': '🛡️',
      'Health': '💊',
      'Medical': '🏥',
      'Education': '📚',
      'Entertainment': '🎬',
      'Credit Card': '💳',
      'Loan': '💰',
      'Taxes': '📝',
      'Savings': '🏦',
      'Donations': '❤️',
      'Home Maintenance': '🔧',
      'HOA': '🏘️',
      'Gym': '💪',
      'Childcare': '👶',
      'Pets': '🐾',
      'Travel': '✈️',
      'Parking': '🅿️',
      'Other': '📁',
    };
    return categoryEmojis[bill.category] ?? '📁';
  }

  Color _getStatusColor() {
    switch (bill.status) {
      case 'paid':
        return const Color(0xFF059669);
      case 'overdue':
        return const Color(0xFFEF4444);
      case 'upcoming':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDate(String dueDate) {
    try {
      final date = DateTime.parse('${dueDate}T00:00:00');
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = date.day;
      final month = months[date.month - 1];
      final year = date.year;
      return '$day $month $year';
    } catch (e) {
      return dueDate;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    return '$day $month $year';
  }

  String _formatDueDate(String dueDate) {
    try {
      final date = DateTime.parse('${dueDate}T00:00:00');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(date.year, date.month, date.day);
      final difference = dueDay.difference(today).inDays;

      // If within 7 days, show "Due in X days"
      if (difference >= 0 && difference <= 7) {
        if (difference == 0) {
          return 'Due today';
        } else if (difference == 1) {
          return 'Due in 1 day';
        } else {
          return 'Due in $difference days';
        }
      }

      // Otherwise show formatted date
      return _formatDate(dueDate);
    } catch (e) {
      return dueDate;
    }
  }

  Widget _buildOverdueDateRow(String dueDate) {
    try {
      final date = DateTime.parse('${dueDate}T00:00:00');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(date.year, date.month, date.day);
      final daysPast = today.difference(dueDay).inDays;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Due Date',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _formatDate(dueDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (daysPast <= 15 && daysPast > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  daysPast == 1
                      ? 'Overdue by 1 day'
                      : 'Overdue by $daysPast days',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      return _buildDetailRow('Due Date', dueDate);
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueBold ? 18 : 14,
                fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveInfo(DateTime paidAt) {
    final now = DateTime.now();
    final daysSincePaid = now.difference(paidAt).inDays;
    final daysUntilArchive = 2 - daysSincePaid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.archive_outlined,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-Archive',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            daysUntilArchive > 0
                ? 'Will auto-archive in $daysUntilArchive day${daysUntilArchive != 1 ? 's' : ''}. Archive manually now if you prefer.'
                : 'Ready to be archived.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.read<BillProvider>();

    // Get additional details from BillHive
    BillHive? billHive;
    String? notes;
    String? reminderTiming;
    String? notificationTime;
    int? repeatCount;
    DateTime? paidAt;

    try {
      billHive = billProvider.bills.firstWhere((b) => b.id == bill.id);
      notes = billHive.notes;
      reminderTiming = billHive.reminderTiming;
      notificationTime = billHive.notificationTime;
      repeatCount = billHive.repeatCount;
      paidAt = billHive.paidAt;
    } catch (e) {
      // Bill not found in provider
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar at top center
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Scrollable content (including header)
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with emoji, title, and edit button
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5E6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                _getCategoryEmoji(),
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bill.category,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Only show edit button for unpaid bills
                          if (bill.status != 'paid')
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xFFF97316),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AddBillScreen(billToEdit: bill),
                                  ),
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFFF97316,
                                ).withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Bill Details
                      _buildDetailRow(
                        'Amount',
                        formatCurrencyFull(bill.amount),
                        valueColor: const Color(0xFF1F2937),
                        valueBold: true,
                      ),
                      if (bill.status == 'paid') ...[
                        _buildDetailRow('Due Date', _formatDate(bill.due)),
                        if (paidAt != null)
                          _buildDetailRow('Paid On', _formatDateTime(paidAt)),
                      ] else if (bill.status == 'overdue')
                        _buildOverdueDateRow(bill.due)
                      else
                        _buildDetailRow('Due Date', _formatDueDate(bill.due)),
                      _buildDetailRow(
                        'Status',
                        bill.status.toUpperCase(),
                        valueColor: _getStatusColor(),
                      ),
                      _buildDetailRow('Recurring', bill.repeat),
                      if (repeatCount != null && repeatCount > 0) ...[
                        if (billHive?.recurringSequence != null)
                          _buildDetailRow(
                            'Occurrence',
                            '${billHive!.recurringSequence} of $repeatCount',
                          )
                        else
                          _buildDetailRow('Repeat Count', '$repeatCount times'),
                      ],
                      if (reminderTiming != null && reminderTiming.isNotEmpty)
                        _buildDetailRow('Reminder', reminderTiming),
                      if (notificationTime != null &&
                          notificationTime.isNotEmpty)
                        _buildDetailRow(
                          'Notification Time',
                          _formatNotificationTime(notificationTime),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          notes != null && notes.isNotEmpty
                              ? notes
                              : 'No notes added for this bill',
                          style: TextStyle(
                            fontSize: 14,
                            color: notes != null && notes.isNotEmpty
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF),
                            fontStyle: notes != null && notes.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                      // Archive info for paid bills
                      if (bill.status == 'paid' && paidAt != null) ...[
                        const SizedBox(height: 20),
                        _buildArchiveInfo(paidAt),
                      ],
                    ],
                  ),
                ),
                // Scroll indicator on the right side
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF97316).withValues(alpha: 0.8),
                          const Color(0xFFF97316).withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons (fixed, not scrollable)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Row(
                  children: [
                    if (bill.status == 'paid')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await billProvider.archiveBill(bill.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${bill.title}" archived'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: const Text('Archive Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Show confirmation dialog first
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF059669,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline,
                                        color: Color(0xFF059669),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Mark as Paid?'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Are you sure you want to mark this bill as paid?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _getCategoryEmoji(),
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  bill.title,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  formatCurrencyFull(
                                                    bill.amount,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Mark as Paid'),
                                  ),
                                ],
                              ),
                            );

                            // Only mark as paid if user confirmed
                            if (confirm == true && context.mounted) {
                              Navigator.pop(context);
                              await billProvider.markBillAsPaid(bill.id);

                              // Show success snackbar
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${bill.title} marked as paid!',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Mark as Paid'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Delete Bill'),
                              content: Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  final dueDate = DateTime.parse(
                                    '${bill.due}T00:00:00',
                                  );
                                  final isPaidOrOverdue =
                                      bill.status == 'paid' ||
                                      dueDate.isBefore(now);

                                  if (isPaidOrOverdue) {
                                    return Text(
                                      'Are you sure you want to delete "${bill.title}"?',
                                    );
                                  } else if (bill.repeat != 'none') {
                                    return Text(
                                      'Are you sure you want to delete "${bill.title}"? This will also delete all future unpaid occurrences. Paid history will be kept.',
                                    );
                                  } else {
                                    return Text(
                                      'Are you sure you want to delete "${bill.title}"?',
                                    );
                                  }
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            Navigator.pop(context);
                            await billProvider.deleteBill(bill.id);

                            // Show snackbar
                            if (context.mounted) {
                              final now = DateTime.now();
                              final dueDate = DateTime.parse(
                                '${bill.due}T00:00:00',
                              );
                              final isPaidOrOverdue =
                                  bill.status == 'paid' ||
                                  dueDate.isBefore(now);
                              final message =
                                  (bill.repeat != 'none' && !isPaidOrOverdue)
                                  ? '"${bill.title}" and future occurrences deleted'
                                  : 'Bill "${bill.title}" deleted';

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context,
    Bill bill, {
    VoidCallback? onMarkPaid,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          BillDetailsBottomSheet(bill: bill, onMarkPaid: onMarkPaid),
    );
  }
}
