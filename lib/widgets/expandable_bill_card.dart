import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../utils/formatters.dart';
import 'bill_details_bottom_sheet.dart';
import 'amount_info_bottom_sheet.dart';

class ExpandableBillCard extends StatelessWidget {
  final Bill bill;
  final bool compactAmounts;
  final int? daysRemaining;
  final VoidCallback? onMarkPaid;

  const ExpandableBillCard({
    super.key,
    required this.bill,
    this.compactAmounts = true,
    this.daysRemaining,
    this.onMarkPaid,
  });

  Color _getStatusColor() {
    switch (bill.status) {
      case 'paid':
        return const Color(0xFF059669); // Green
      case 'overdue':
        return const Color(0xFFEF4444); // Red
      case 'upcoming':
        return const Color(0xFFFF8C00); // Orange
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  Widget _buildDueDateText() {
    try {
      final date = DateTime.parse('${bill.due}T00:00:00');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(date.year, date.month, date.day);
      final difference = dueDay.difference(today).inDays;

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

      String prefix = '';
      String dateText = '';

      // For paid bills
      if (bill.status == 'paid') {
        prefix = 'Paid on: ';
        dateText = '$day $month $year';
      }
      // For overdue bills
      else if (bill.status == 'overdue') {
        final daysPast = -difference;
        if (daysPast <= 7) {
          if (daysPast == 0) {
            return const Text(
              'Due today',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            );
          } else if (daysPast == 1) {
            prefix = 'Overdue by: ';
            dateText = '1 day';
          } else {
            prefix = 'Overdue by: ';
            dateText = '$daysPast days';
          }
        } else {
          prefix = 'Overdue on: ';
          dateText = '$day $month $year';
        }
      }
      // For upcoming bills
      else {
        if (difference >= 0 && difference <= 7) {
          if (difference == 0) {
            return const Text(
              'Due today',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFFF8C00),
                fontWeight: FontWeight.w700,
              ),
            );
          } else if (difference == 1) {
            prefix = 'Due in: ';
            dateText = '1 day';
          } else {
            prefix = 'Due in: ';
            dateText = '$difference days';
          }
        } else {
          prefix = 'Due on: ';
          dateText = '$day $month $year';
        }
      }

      // Get color based on status
      Color dateColor;
      if (bill.status == 'paid') {
        dateColor = const Color(0xFF059669); // Green
      } else if (bill.status == 'overdue') {
        dateColor = const Color(0xFFEF4444); // Red
      } else {
        dateColor = const Color(0xFFFF8C00); // Orange
      }

      // For paid bills, no icon here (icon is next to status)
      if (bill.status == 'paid') {
        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: prefix,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: dateText,
                style: TextStyle(color: dateColor, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      }

      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(
              text: prefix,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: dateText,
              style: TextStyle(color: dateColor, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    } catch (e) {
      return Text(
        bill.due,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w700,
        ),
      );
    }
  }

  String _getCategoryEmoji() {
    // Match emojis from add bill screen categories
    switch (bill.category) {
      case 'Subscriptions':
        return '📋';
      case 'Rent':
        return '🏠';
      case 'Utilities':
        return '💡';
      case 'Electricity':
        return '⚡';
      case 'Water':
        return '💧';
      case 'Gas':
        return '🔥';
      case 'Internet':
        return '🌐';
      case 'Phone':
        return '📱';
      case 'Streaming':
        return '📺';
      case 'Groceries':
        return '🛒';
      case 'Transport':
        return '🚌';
      case 'Fuel':
        return '⛽';
      case 'Insurance':
        return '🛡️';
      case 'Health':
        return '💊';
      case 'Medical':
        return '🏥';
      case 'Education':
        return '📚';
      case 'Entertainment':
        return '🎬';
      case 'Credit Card':
        return '💳';
      case 'Loan':
        return '💰';
      case 'Taxes':
        return '📝';
      case 'Savings':
        return '🏦';
      case 'Donations':
        return '❤️';
      case 'Home Maintenance':
        return '🔧';
      case 'HOA':
        return '🏘️';
      case 'Gym':
        return '💪';
      case 'Childcare':
        return '👶';
      case 'Pets':
        return '🐾';
      case 'Travel':
        return '✈️';
      case 'Parking':
        return '🅿️';
      case 'Other':
        return '📁';
      default:
        return '📁';
    }
  }

  void _showManageBottomSheet(BuildContext context) {
    BillDetailsBottomSheet.show(context, bill, onMarkPaid: onMarkPaid);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Icon (no container)
            Text(_getCategoryEmoji(), style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            // Left Side - Bill Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    bill.category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(children: [Flexible(child: _buildDueDateText())]),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right Side - Amount, Status, Manage
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bill.amount >= 1000
                          ? formatCurrencyShort(bill.amount)
                          : formatCurrencyFull(bill.amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (bill.amount >= 1000) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          AmountInfoBottomSheet.show(
                            context,
                            amount: bill.amount,
                            billCount: 1,
                            title: bill.title,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF8C00,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFFFF8C00),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bill.status == 'paid')
                      const Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Color(0xFF059669),
                      ),
                    if (bill.status == 'paid') const SizedBox(width: 4),
                    Text(
                      bill.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ElevatedButton(
                  onPressed: () => _showManageBottomSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Manage',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
