import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../utils/formatters.dart';
import '../utils/text_styles.dart';
import 'bill_details_bottom_sheet.dart';
import 'amount_info_bottom_sheet.dart';

class ExpandableBillCard extends StatelessWidget {
  final Bill bill;
  final bool compactAmounts;
  final int? daysRemaining;
  final VoidCallback? onMarkPaid;
  final bool isHighlighted;

  const ExpandableBillCard({
    super.key,
    required this.bill,
    this.compactAmounts = true,
    this.daysRemaining,
    this.onMarkPaid,
    this.isHighlighted = false,
  });

  Widget _buildDueDateText() {
    try {
      final date = DateTime.parse('${bill.due}T00:00:00');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(date.year, date.month, date.day);
      final difference = dueDay.difference(today).inDays;
      debugPrint(
        '🔍 Bill "${bill.title}": due="${bill.due}", today=$today, dueDay=$dueDay, diff=$difference',
      );

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
        final paidDate = bill.paidAt ?? date;
        final pDay = paidDate.day;
        final pMonth = months[paidDate.month - 1];
        final pYear = paidDate.year;
        dateText = '$pDay $pMonth $pYear';
      }
      // For overdue bills
      else if (bill.status == 'overdue') {
        final daysPast = -difference;
        if (daysPast <= 7) {
          if (daysPast == 0) {
            return Text(
              'Due today',
              style: AppTextStyles.dueDate(color: const Color(0xFFEF4444)),
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
            return Text(
              'Due today',
              style: AppTextStyles.dueDate(color: const Color(0xFFF97316)),
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
        dateColor = const Color(0xFFF97316); // Orange
      }

      // For paid bills, no icon here (icon is next to status)
      if (bill.status == 'paid') {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: prefix, style: AppTextStyles.dueDatePrefix()),
              TextSpan(
                text: dateText,
                style: AppTextStyles.dueDate(color: dateColor),
              ),
            ],
          ),
        );
      }

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: AppTextStyles.dueDatePrefix()),
            TextSpan(
              text: dateText,
              style: AppTextStyles.dueDate(color: dateColor),
            ),
          ],
        ),
      );
    } catch (e) {
      return Text(bill.due, style: AppTextStyles.dueDate());
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: const Color(0xFFF97316), width: 2)
            : null,
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ]
            : [
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
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Icon in container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getCategoryEmoji(),
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            // Left Side - Bill Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: AppTextStyles.billTitle(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  Text(bill.category, style: AppTextStyles.label()),
                  const SizedBox(height: 8),
                  Row(children: [Flexible(child: _buildDueDateText())]),
                ],
              ),
            ),
            const SizedBox(width: 16),
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
                      style: AppTextStyles.amount(),
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
                              0xFFF97316,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showManageBottomSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Manage', style: AppTextStyles.button()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
