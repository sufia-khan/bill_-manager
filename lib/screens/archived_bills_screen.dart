import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../utils/formatters.dart';
import '../widgets/amount_info_bottom_sheet.dart';
import '../widgets/custom_snackbar.dart';

class ArchivedBillsScreen extends StatefulWidget {
  const ArchivedBillsScreen({super.key});

  @override
  State<ArchivedBillsScreen> createState() => _ArchivedBillsScreenState();
}

class _ArchivedBillsScreenState extends State<ArchivedBillsScreen> {
  String selectedCategory = 'All';
  bool _compactAmounts = true;

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();

    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        final archivedBills = billProvider.getArchivedBills();

        // Create a map to store bill data with dates
        final billsWithDates = archivedBills.map((billHive) {
          return {
            'bill': Bill(
              id: billHive.id,
              title: billHive.title,
              vendor: billHive.vendor,
              amount: billHive.amount,
              due: billHive.dueAt.toIso8601String().split('T')[0],
              repeat: billHive.repeat,
              category: billHive.category,
              status: 'paid',
            ),
            'paidAt': billHive.paidAt,
            'dueAt': billHive.dueAt,
          };
        }).toList();

        final filteredBillsWithDates = selectedCategory == 'All'
            ? billsWithDates
            : billsWithDates
                  .where(
                    (data) =>
                        (data['bill'] as Bill).category == selectedCategory,
                  )
                  .toList();

        final filteredBills = filteredBillsWithDates
            .map((data) => data['bill'] as Bill)
            .toList();

        return Scaffold(
          backgroundColor: Colors.white,
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
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archived Bills',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
            actions: [
              if (archivedBills.isNotEmpty)
                IconButton(
                  onPressed: () => _showDeleteAllDialog(billProvider),
                  icon: const Icon(
                    Icons.delete_sweep,
                    color: Color(0xFFEF4444),
                  ),
                  tooltip: 'Delete All',
                ),
            ],
          ),
          body: archivedBills.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSummary(filteredBills.length, filteredBills),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredBillsWithDates.length,
                        itemBuilder: (context, index) {
                          final data = filteredBillsWithDates[index];
                          return _buildArchivedBillCard(
                            data['bill'] as Bill,
                            data['paidAt'] as DateTime?,
                            data['dueAt'] as DateTime,
                            billProvider,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.archive_outlined,
                size: 60,
                color: Color(0xFFF97316),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Archived Bills',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bills are automatically archived 30 days after payment\nand deleted after 90 days',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(int count, List<Bill> bills) {
    final totalAmount = bills.fold(0.0, (sum, bill) => sum + bill.amount);
    final formattedAmount = _compactAmounts
        ? formatCurrencyShort(totalAmount)
        : formatCurrencyFull(totalAmount);
    final fullAmount = formatCurrencyFull(totalAmount);
    final isFormatted = formattedAmount != fullAmount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE5CC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.archive, color: Color(0xFFF97316), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Archived Bill${count != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Total: $formattedAmount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    if (isFormatted) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          AmountInfoBottomSheet.show(
                            context,
                            amount: totalAmount,
                            billCount: count,
                            title: 'Archived Bills Total',
                            formattedAmount: formattedAmount,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedBillCard(
    Bill bill,
    DateTime? paidAt,
    DateTime dueAt,
    BillProvider billProvider,
  ) {
    final formattedAmount = _compactAmounts
        ? formatCurrencyShort(bill.amount)
        : formatCurrencyFull(bill.amount);
    final fullAmount = formatCurrencyFull(bill.amount);
    final isFormatted = formattedAmount != fullAmount;

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteDialog(bill);
      },
      onDismissed: (direction) async {
        await billProvider.deleteArchivedBill(bill.id);
        if (mounted) {
          CustomSnackBar.showError(
            context,
            '${bill.title} deleted',
            duration: const Duration(seconds: 2),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                        const SizedBox(height: 4),
                        Text(
                          bill.vendor,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Due: ${_formatDate(dueAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            formattedAmount,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (isFormatted) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                AmountInfoBottomSheet.show(
                                  context,
                                  amount: bill.amount,
                                  billCount: 1,
                                  title: bill.title,
                                  formattedAmount: formattedAmount,
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
                      const SizedBox(height: 4),
                      Text(
                        bill.repeat != 'none' ? bill.repeat : 'One-time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Paid: ${paidAt != null ? _formatDate(paidAt) : 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRestoreDialog(bill, billProvider),
                    icon: const Icon(
                      Icons.restore,
                      size: 18,
                      color: Color(0xFFF97316),
                    ),
                    label: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(Bill bill) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Bill?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${bill.title}"?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAllDialog(BillProvider billProvider) async {
    final archivedBills = billProvider.getArchivedBills();
    final billCount = archivedBills.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete All?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete all $billCount archived bills?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Delete all archived bills permanently
      for (final bill in archivedBills) {
        await billProvider.deleteArchivedBill(bill.id);
      }
      if (mounted) {
        CustomSnackBar.showSuccess(
          context,
          'Permanently deleted $billCount archived bills',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _showRestoreDialog(Bill bill, BillProvider billProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Color(0xFFF97316), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Restore Bill?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to restore "${bill.title}"?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF97316), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will move the bill back to the Paid tab',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await billProvider.restoreBill(bill.id);
      if (mounted) {
        // Force refresh to remove from archived list
        setState(() {});
        CustomSnackBar.showSuccess(
          context,
          '${bill.title} restored successfully!',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
}
