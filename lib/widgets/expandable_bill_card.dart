import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bill.dart';
import '../utils/formatters.dart';
import '../utils/text_styles.dart';
import 'bill_details_bottom_sheet.dart';

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
      Color dateColor;

      // For paid bills
      if (bill.status == 'paid') {
        prefix = 'Paid on ';
        final paidDate = bill.paidAt ?? date;
        final pDay = paidDate.day;
        final pMonth = months[paidDate.month - 1];
        dateText = '$pDay $pMonth';
        dateColor = const Color(0xFF059669); // Green
      }
      // For overdue bills
      else if (bill.status == 'overdue') {
        dateColor = const Color(0xFFEF4444); // Red
        final daysPast = -difference;
        if (daysPast <= 7) {
          if (daysPast == 0) {
            return Text(
              'Due today',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dateColor,
              ),
            );
          } else {
            prefix = 'Overdue by ';
            dateText = '$daysPast days';
          }
        } else {
          prefix = 'Overdue ';
          dateText = '$day $month';
        }
      }
      // For upcoming bills
      else {
        dateColor = const Color(0xFFF97316); // Orange
        if (difference >= 0 && difference <= 7) {
          if (difference == 0) {
            return Text(
              'Due today',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dateColor,
              ),
            );
          } else if (difference == 1) {
            prefix = 'Due in ';
            dateText = '1 day';
          } else {
            prefix = 'Due in ';
            dateText = '$difference days';
          }
        } else {
          prefix = 'Due ';
          dateText = '$day $month $year';
          // Use grey for non-urgent upcoming dates
          dateColor = const Color(0xFF6B7280);
        }
      }

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: dateColor,
              ),
            ),
            TextSpan(
              text: dateText,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dateColor,
              ),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isHighlighted
            ? Border.all(color: const Color(0xFFF97316), width: 2)
            : Border.all(color: Colors.transparent, width: 0),
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
                  color: const Color(0xFF000000).withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showManageBottomSheet(context),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED), // Very light orange
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getCategoryEmoji(),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Middle Section: Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          bill.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937), // Grey 900
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bill.category,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9CA3AF), // Grey 400
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _buildDueDateText(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right Section: Amount & Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        bill.amount >= 1000
                            ? formatCurrencyShort(bill.amount)
                            : formatCurrencyFull(bill.amount),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => _showManageBottomSheet(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6), // Blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            elevation: 0,
                            shape: const StadiumBorder(),
                            textStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Manage'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
