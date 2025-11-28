import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../utils/formatters.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../widgets/amount_info_bottom_sheet.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedTabIndex = 1;
  String _activeTab = 'total';
  bool _showingSecondHalf =
      false; // false = first 6 months, true = next 6 months

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  // Find the earliest bill month based on active tab
  DateTime? _getFirstBillMonth(List<Bill> bills) {
    if (bills.isEmpty) return null;

    // Filter bills based on active tab
    List<Bill> filteredBills;
    switch (_activeTab) {
      case 'paid':
        filteredBills = bills.where((b) => b.status == 'paid').toList();
        break;
      case 'pending':
        filteredBills = bills.where((b) => b.status == 'upcoming').toList();
        break;
      case 'overdue':
        filteredBills = bills.where((b) => b.status == 'overdue').toList();
        break;
      default:
        filteredBills = bills;
    }

    if (filteredBills.isEmpty) return null;

    DateTime? earliest;
    for (var bill in filteredBills) {
      final dueDate = DateTime.parse('${bill.due}T00:00:00');
      if (earliest == null || dueDate.isBefore(earliest)) {
        earliest = dueDate;
      }
    }
    return earliest != null ? DateTime(earliest.year, earliest.month, 1) : null;
  }

  // Calculate monthly data from bills starting from first bill month
  List<Map<String, dynamic>> _calculateMonthlyData(
    List<Bill> bills,
    bool showSecondHalf,
  ) {
    final monthlyData = <Map<String, dynamic>>[];
    const months = [
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

    // Get the first bill month
    final firstBillMonth = _getFirstBillMonth(bills);
    if (firstBillMonth == null) {
      // No bills, show current month as start
      final now = DateTime.now();
      final startMonth = DateTime(now.year, now.month, 1);
      for (int i = 0; i < 6; i++) {
        final month = DateTime(
          startMonth.year,
          startMonth.month + (showSecondHalf ? 6 : 0) + i,
          1,
        );
        monthlyData.add({
          'month': months[month.month - 1],
          'year': month.year,
          'total': 0.0,
          'paid': 0.0,
          'pending': 0.0,
          'overdue': 0.0,
        });
      }
      return monthlyData;
    }

    // Calculate data for 6 months starting from first bill month
    final startOffset = showSecondHalf ? 6 : 0;
    for (int i = 0; i < 6; i++) {
      final month = DateTime(
        firstBillMonth.year,
        firstBillMonth.month + startOffset + i,
        1,
      );

      final monthBills = bills.where((bill) {
        final dueDate = DateTime.parse('${bill.due}T00:00:00');
        return dueDate.year == month.year && dueDate.month == month.month;
      }).toList();

      monthlyData.add({
        'month': months[month.month - 1],
        'year': month.year,
        'total': monthBills.fold(0.0, (sum, bill) => sum + bill.amount),
        'paid': monthBills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'pending': monthBills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'overdue': monthBills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });
    }

    return monthlyData;
  }

  String _getChartPeriodLabel(List<Bill> bills) {
    final firstBillMonth = _getFirstBillMonth(bills);
    if (firstBillMonth == null) return '';

    const months = [
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

    if (_showingSecondHalf) {
      final startMonth = DateTime(
        firstBillMonth.year,
        firstBillMonth.month + 6,
        1,
      );
      final endMonth = DateTime(
        firstBillMonth.year,
        firstBillMonth.month + 11,
        1,
      );
      return '${months[startMonth.month - 1]} ${startMonth.year} - ${months[endMonth.month - 1]} ${endMonth.year}';
    } else {
      final endMonth = DateTime(
        firstBillMonth.year,
        firstBillMonth.month + 5,
        1,
      );
      return '${months[firstBillMonth.month - 1]} ${firstBillMonth.year} - ${months[endMonth.month - 1]} ${endMonth.year}';
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_outlined, 'Home'),
            _buildNavItem(1, Icons.analytics_outlined, 'Analytics'),
            _buildNavItem(2, Icons.calendar_today_outlined, 'Calendar'),
            _buildNavItem(3, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        // Don't navigate if already on analytics screen
        if (index == 1) return;

        setState(() {
          _selectedTabIndex = index;
        });

        // Handle navigation for different tabs
        if (index == 0) {
          // Home tab - pop back to root
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 2) {
          // Calendar tab
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.pushNamed(context, '/calendar');
        } else if (index == 3) {
          // Settings tab
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.pushNamed(context, '/settings');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFFF97316)
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFFF97316)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        final bills = billProvider.bills
            .where(
              (billHive) => !billHive.isArchived,
            ) // Filter out archived bills
            .map(
              (billHive) => Bill(
                id: billHive.id,
                title: billHive.title,
                vendor: billHive.vendor,
                amount: billHive.amount,
                due: billHive.dueAt.toIso8601String().split('T')[0],
                repeat: billHive.repeat,
                category: billHive.category,
                status: billHive.isPaid
                    ? 'paid'
                    : (billHive.dueAt.isBefore(DateTime.now())
                          ? 'overdue'
                          : 'upcoming'),
              ),
            )
            .toList();

        final monthlyData = _calculateMonthlyData(bills, _showingSecondHalf);

        // Calculate totals for summary cards
        final totalAmount = bills.fold(0.0, (sum, bill) => sum + bill.amount);
        final totalCount = bills.length;
        final paidAmount = bills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount);
        final paidCount = bills.where((b) => b.status == 'paid').length;
        final pendingAmount = bills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount);
        final pendingCount = bills.where((b) => b.status == 'upcoming').length;
        final overdueAmount = bills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount);
        final overdueCount = bills.where((b) => b.status == 'overdue').length;

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
                color: Color(0xFFF97316),
                size: 20,
              ),
            ),
            title: const Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF97316),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Cards Grid
                _buildSummaryCards(
                  totalAmount,
                  paidAmount,
                  pendingAmount,
                  overdueAmount,
                  totalCount,
                  paidCount,
                  pendingCount,
                  overdueCount,
                ),
                const SizedBox(height: 28),
                // Bar Chart Section
                _buildBarChart(monthlyData, bills),
                const SizedBox(height: 28),
                // Top Categories Section
                _buildTopCategories(bills),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopCategories(List<Bill> bills) {
    // Calculate spending by category
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCount = {};

    for (var bill in bills) {
      final category = bill.category;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + bill.amount;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    // Sort categories by total amount
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 categories
    final topCategories = sortedCategories.take(5).toList();

    if (topCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get category emojis and colors (matching add_bill_screen)
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

    final categoryColors = {
      'Subscriptions': const Color(0xFF8B5CF6),
      'Rent': const Color(0xFF3B82F6),
      'Utilities': const Color(0xFFF97316),
      'Electricity': const Color(0xFFF59E0B),
      'Water': const Color(0xFF06B6D4),
      'Gas': const Color(0xFFEF4444),
      'Internet': const Color(0xFF10B981),
      'Phone': const Color(0xFFEC4899),
      'Streaming': const Color(0xFF8B5CF6),
      'Groceries': const Color(0xFF059669),
      'Transport': const Color(0xFF6366F1),
      'Fuel': const Color(0xFFF59E0B),
      'Insurance': const Color(0xFF059669),
      'Health': const Color(0xFFDC2626),
      'Medical': const Color(0xFFDC2626),
      'Education': const Color(0xFF6366F1),
      'Entertainment': const Color(0xFFF59E0B),
      'Credit Card': const Color(0xFFEC4899),
      'Loan': const Color(0xFF8B5CF6),
      'Taxes': const Color(0xFF6B7280),
      'Savings': const Color(0xFF10B981),
      'Donations': const Color(0xFFEF4444),
      'Home Maintenance': const Color(0xFF6B7280),
      'HOA': const Color(0xFF3B82F6),
      'Gym': const Color(0xFF10B981),
      'Childcare': const Color(0xFFEC4899),
      'Pets': const Color(0xFFF59E0B),
      'Travel': const Color(0xFF06B6D4),
      'Parking': const Color(0xFF6B7280),
      'Other': const Color(0xFF6B7280),
    };

    // Calculate total spending
    final totalSpending = categoryTotals.values.reduce((a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFFF97316),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Categories',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '${topCategories.length} categories',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Total spending badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrencyShort(totalSpending),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (totalSpending >= 1000) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          AmountInfoBottomSheet.show(
                            context,
                            amount: totalSpending,
                            billCount: bills.length,
                            title: 'Total Spending',
                            formattedAmount: formatCurrencyShort(totalSpending),
                          );
                        },
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Divider
          Container(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 16),
          ...topCategories.map((entry) {
            final category = entry.key;
            final amount = entry.value;
            final emoji = categoryEmojis[category] ?? '📁';
            final color = categoryColors[category] ?? const Color(0xFF6B7280);
            final percentage = (amount / totalSpending * 100);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrencyShort(amount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                if (amount >= 1000) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      AmountInfoBottomSheet.show(
                                        context,
                                        amount: amount,
                                        billCount: categoryCount[category] ?? 0,
                                        title: category,
                                        formattedAmount: formatCurrencyShort(
                                          amount,
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  color: Colors.grey.shade200,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${percentage.toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    double totalAmount,
    double paidAmount,
    double pendingAmount,
    double overdueAmount,
    int totalCount,
    int paidCount,
    int pendingCount,
    int overdueCount,
  ) {
    return Column(
      children: [
        // First row - Total and Paid
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                tab: 'total',
                color: const Color(0xFF8B5CF6),
                icon: Icons.receipt_long_rounded,
                title: 'Total Bills',
                amount: formatCurrencyFull(totalAmount),
                count: totalCount,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                tab: 'paid',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_rounded,
                title: 'Paid Bills',
                amount: formatCurrencyFull(paidAmount),
                count: paidCount,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Second row - Upcoming and Overdue
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                tab: 'pending',
                color: const Color(0xFF3B82F6),
                icon: Icons.schedule_rounded,
                title: 'Upcoming',
                amount: formatCurrencyFull(pendingAmount),
                count: pendingCount,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                tab: 'overdue',
                color: const Color(0xFFEF4444),
                icon: Icons.warning_rounded,
                title: 'Overdue',
                amount: formatCurrencyFull(overdueAmount),
                count: overdueCount,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String tab,
    required Color color,
    required IconData icon,
    required String title,
    required String amount,
    required int count,
  }) {
    final isActive = _activeTab == tab;
    // Parse the full amount to get the numeric value
    final numericAmount = double.parse(
      amount.replaceAll(RegExp(r'[^\d.]'), ''),
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
          _showingSecondHalf = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    formatCurrencyShort(numericAmount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                  ),
                ),
                if (numericAmount >= 1000)
                  GestureDetector(
                    onTap: () {
                      AmountInfoBottomSheet.show(
                        context,
                        amount: numericAmount,
                        billCount: count,
                        title: title,
                        formattedAmount: formatCurrencyShort(numericAmount),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Bill count
            Text(
              '$count bill${count != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    List<Map<String, dynamic>> monthlyData,
    List<Bill> bills,
  ) {
    Color activeColor;
    String chartTitle;

    switch (_activeTab) {
      case 'total':
        activeColor = const Color(0xFF8B5CF6);
        chartTitle = 'Monthly Total Bills';
        break;
      case 'paid':
        activeColor = const Color(0xFF10B981);
        chartTitle = 'Monthly Paid Bills';
        break;
      case 'pending':
        activeColor = const Color(0xFF3B82F6);
        chartTitle = 'Monthly Upcoming Bills';
        break;
      case 'overdue':
        activeColor = const Color(0xFFEF4444);
        chartTitle = 'Monthly Overdue Bills';
        break;
      default:
        activeColor = const Color(0xFF8B5CF6);
        chartTitle = 'Monthly Bills';
    }

    // Calculate max value for chart
    double maxValue = 0;
    for (var data in monthlyData) {
      final value = (data[_activeTab] ?? 0).toDouble();
      if (value > maxValue) maxValue = value;
    }
    final dynamicMaxY = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 1000.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Header
          Row(
            children: [
              // Color indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chartTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getChartPeriodLabel(bills),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _showingSecondHalf
                          ? () => setState(() => _showingSecondHalf = false)
                          : null,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: _showingSecondHalf
                              ? const Color(0xFFF97316)
                              : Colors.grey.shade300,
                          size: 22,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    InkWell(
                      onTap: !_showingSecondHalf
                          ? () => setState(() => _showingSecondHalf = true)
                          : null,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: !_showingSecondHalf
                              ? const Color(0xFFF97316)
                              : Colors.grey.shade300,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: dynamicMaxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 0.8,
                      dashArray: [8, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthlyData[index]['month'],
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: dynamicMaxY / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          formatCurrencyShort(value),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.normal,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: dynamicMaxY,
                barGroups: monthlyData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final value = (data[_activeTab] ?? 0).toDouble();

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: activeColor,
                        width: 22,
                        borderRadius: BorderRadius.circular(8),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: dynamicMaxY,
                          color: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = monthlyData[group.x]['month'];
                      final year = monthlyData[group.x]['year'];

                      return BarTooltipItem(
                        '$month $year\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: formatCurrencyFull(rod.toY),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
