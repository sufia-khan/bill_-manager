import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../services/notification_history_service.dart';
import '../widgets/animated_subtitle.dart';
import '../widgets/expandable_bill_card.dart';
import '../widgets/amount_info_bottom_sheet.dart';
import '../utils/formatters.dart';
import '../utils/text_styles.dart';
import 'add_bill_screen.dart';
import 'notification_screen.dart';

class BillManagerScreen extends StatefulWidget {
  const BillManagerScreen({super.key});

  @override
  State<BillManagerScreen> createState() => _BillManagerScreenState();
}

class _BillManagerScreenState extends State<BillManagerScreen> {
  // Bills are now loaded from BillProvider - no hardcoded data!

  // Category data with emojis (matching add bill screen)
  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'emoji': '📱'},
    {'name': 'Subscriptions', 'emoji': '📋'},
    {'name': 'Rent', 'emoji': '🏠'},
    {'name': 'Utilities', 'emoji': '💡'},
    {'name': 'Electricity', 'emoji': '⚡'},
    {'name': 'Water', 'emoji': '💧'},
    {'name': 'Gas', 'emoji': '🔥'},
    {'name': 'Internet', 'emoji': '🌐'},
    {'name': 'Phone', 'emoji': '📱'},
    {'name': 'Streaming', 'emoji': '📺'},
    {'name': 'Groceries', 'emoji': '🛒'},
    {'name': 'Transport', 'emoji': '🚌'},
    {'name': 'Fuel', 'emoji': '⛽'},
    {'name': 'Insurance', 'emoji': '🛡️'},
    {'name': 'Health', 'emoji': '💊'},
    {'name': 'Medical', 'emoji': '🏥'},
    {'name': 'Education', 'emoji': '📚'},
    {'name': 'Entertainment', 'emoji': '🎬'},
    {'name': 'Credit Card', 'emoji': '💳'},
    {'name': 'Loan', 'emoji': '💰'},
    {'name': 'Taxes', 'emoji': '📝'},
    {'name': 'Savings', 'emoji': '🏦'},
    {'name': 'Donations', 'emoji': '❤️'},
    {'name': 'Home Maintenance', 'emoji': '🔧'},
    {'name': 'HOA', 'emoji': '🏘️'},
    {'name': 'Gym', 'emoji': '💪'},
    {'name': 'Childcare', 'emoji': '👶'},
    {'name': 'Pets', 'emoji': '🐾'},
    {'name': 'Travel', 'emoji': '✈️'},
    {'name': 'Parking', 'emoji': '🅿️'},
    {'name': 'Other', 'emoji': '📁'},
  ];

  String selectedCategory = 'All';
  String selectedStatus = 'upcoming'; // upcoming, overdue, paid
  int _selectedTabIndex = 0;
  bool _compactAmounts = true;
  final bool _showSettings = false;

  @override
  void initState() {
    super.initState();

    // Load bills when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  // Totals are now calculated in BillProvider

  @override
  Widget build(BuildContext context) {
    // Listen to currency changes to rebuild UI
    context.watch<CurrencyProvider>();

    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        // Debug: Print bill count
        print('DEBUG: Total bills in provider: ${billProvider.bills.length}');

        // Convert BillHive to legacy Bill format for UI
        // Show unpaid bills AND paid bills that haven't been archived yet (within 2 days)
        final now = DateTime.now();
        final bills = billProvider.bills
            .where((billHive) => !billHive.isArchived && !billHive.isDeleted)
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
                    : (billHive.dueAt.isBefore(now) ? 'overdue' : 'upcoming'),
              ),
            )
            .toList();

        // Filter by status first, then by category
        final statusFilteredBills = bills
            .where((b) => b.status == selectedStatus)
            .toList();

        final filteredBills = selectedCategory == 'All'
            ? statusFilteredBills
            : statusFilteredBills
                  .where((b) => b.category == selectedCategory)
                  .toList();

        final thisMonthTotal = billProvider.getThisMonthTotal();
        final next7DaysTotal = billProvider.getNext7DaysTotal();

        // Debug: Print calculated values
        print(
          'DEBUG: This month total: $thisMonthTotal, count will be calculated',
        );
        print(
          'DEBUG: Next 7 days total: $next7DaysTotal, count will be calculated',
        );

        // Calculate counts (reuse 'now' from above)
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final startOfToday = DateTime(now.year, now.month, now.day);
        final endOf7Days = startOfToday.add(
          const Duration(days: 7, hours: 23, minutes: 59, seconds: 59),
        );

        print('DEBUG: Date ranges - Month: $startOfMonth to $endOfMonth');
        print('DEBUG: Date ranges - Next 7 days: $startOfToday to $endOf7Days');

        // Filter for UPCOMING bills only (not paid, not overdue)
        final thisMonthBills = bills.where((bill) {
          final dueDate = DateTime.parse('${bill.due}T00:00:00');
          final isInRange =
              !dueDate.isBefore(startOfMonth) && !dueDate.isAfter(endOfMonth);
          final isUpcoming = bill.status == 'upcoming'; // Only upcoming bills
          if (isInRange && isUpcoming) {
            print(
              'DEBUG: Upcoming bill in this month: ${bill.title} - Due: $dueDate - Amount: ${bill.amount}',
            );
          }
          return isInRange && isUpcoming;
        }).toList();
        final thisMonthCount = thisMonthBills.length;
        final thisMonthUpcomingTotal = thisMonthBills.fold(
          0.0,
          (sum, bill) => sum + bill.amount,
        );

        final next7DaysBills = bills.where((bill) {
          final dueDate = DateTime.parse('${bill.due}T00:00:00');
          final isInRange =
              !dueDate.isBefore(startOfToday) && !dueDate.isAfter(endOf7Days);
          final isUpcoming = bill.status == 'upcoming'; // Only upcoming bills
          if (isInRange && isUpcoming) {
            print(
              'DEBUG: Upcoming bill in next 7 days: ${bill.title} - Due: $dueDate - Amount: ${bill.amount}',
            );
          }
          return isInRange && isUpcoming;
        }).toList();
        final next7DaysCount = next7DaysBills.length;
        final next7DaysUpcomingTotal = next7DaysBills.fold(
          0.0,
          (sum, bill) => sum + bill.amount,
        );

        print('DEBUG: This month count: $thisMonthCount');
        print('DEBUG: Next 7 days count: $next7DaysCount');

        final filteredCount = filteredBills.length;
        final filteredAmount = filteredBills.fold(
          0.0,
          (sum, bill) => sum + bill.amount,
        );

        return _buildScaffold(
          context,
          bills,
          filteredBills,
          thisMonthUpcomingTotal,
          thisMonthCount,
          next7DaysUpcomingTotal,
          next7DaysCount,
          filteredCount,
          filteredAmount,
          billProvider.isLoading,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<Bill> bills,
    List<Bill> filteredBills,
    double thisMonthTotal,
    int thisMonthCount,
    double next7DaysTotal,
    int next7DaysCount,
    int filteredCount,
    double filteredAmount,
    bool isLoading,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: Column(
        children: [
          _buildUnifiedHeader(
            thisMonthTotal,
            thisMonthCount,
            next7DaysTotal,
            next7DaysCount,
          ),
          Expanded(
            child: _buildBody(
              filteredBills,
              thisMonthTotal,
              next7DaysTotal,
              filteredCount,
              filteredAmount,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildUnifiedHeader(
    double thisMonthTotal,
    int thisMonthCount,
    double next7DaysTotal,
    int next7DaysCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BillMinder', style: AppTextStyles.appTitle()),
                          const AnimatedSubtitle(),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF97316,
                            ).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationScreen(),
                                ),
                              );
                              // Refresh to update badge after viewing notifications
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFFF97316),
                              size: 24,
                            ),
                            tooltip: 'Notifications',
                          ),
                          // Unread notification badge
                          if (NotificationHistoryService.getUnreadCount() > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'This month',
                        thisMonthTotal,
                        '$thisMonthCount bill${thisMonthCount != 1 ? 's' : ''}',
                        const Text('📅', style: TextStyle(fontSize: 20)),
                        thisMonthCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Next 7 days',
                        next7DaysTotal,
                        '$next7DaysCount bill${next7DaysCount != 1 ? 's' : ''}',
                        const Text('⏰', style: TextStyle(fontSize: 20)),
                        next7DaysCount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    List<Bill> filteredBills,
    double thisMonthTotal,
    double next7DaysTotal,
    int filteredCount,
    double filteredAmount,
  ) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showSettings) _buildSettingsSection(),
              _buildFilterSection(),
              const SizedBox(height: 20),
              _buildFilteredSection(filteredCount, filteredAmount),
              const SizedBox(height: 20),
              _buildBillsList(filteredBills),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                label: 'Compact amounts setting',
                value: _compactAmounts ? 'enabled' : 'disabled',
                child: const Text(
                  'Compact amounts',
                  style: TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                ),
              ),
              Switch(
                value: _compactAmounts,
                onChanged: (value) {
                  setState(() {
                    _compactAmounts = value;
                  });
                },
                activeTrackColor: const Color(
                  0xFFF97316,
                ).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFFF97316),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    String subtitle,
    Widget icon,
    int billCount,
  ) {
    return GestureDetector(
      onTap: () {
        AmountInfoBottomSheet.show(
          context,
          amount: amount,
          billCount: billCount,
          title: title,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: title == 'This month'
                ? [const Color(0xFF3B82F6), const Color(0xFF4F46E5)]
                : [const Color(0xFFF97316), const Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (title == 'This month'
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFF97316))
                      .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount >= 1000
                        ? formatCurrencyShort(amount)
                        : formatCurrencyFull(amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (amount >= 1000) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Row(
      children: [
        Expanded(child: _buildStatusTab('upcoming', 'Upcoming')),
        Expanded(child: _buildStatusTab('overdue', 'Overdue')),
        Expanded(child: _buildStatusTab('paid', 'Paid')),
      ],
    );
  }

  Widget _buildStatusTab(String status, String label) {
    final isSelected = selectedStatus == status;

    // Get accent color based on status
    Color accentColor;
    switch (status) {
      case 'upcoming':
        accentColor = const Color(0xFF3B82F6); // blue-500
        break;
      case 'overdue':
        accentColor = const Color(0xFFEF4444); // red-500
        break;
      case 'paid':
        accentColor = const Color(0xFF10B981); // emerald-500
        break;
      default:
        accentColor = const Color(0xFF3B82F6);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? accentColor : const Color(0xFF9CA3AF),
            ),
            child: Text(label),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 24 : 0,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredSection(int count, double amount) {
    final formattedAmount = _compactAmounts
        ? formatCurrencyShort(amount)
        : formatCurrencyFull(amount);
    final fullAmount = formatCurrencyFull(amount);
    final isFormatted = formattedAmount != fullAmount;

    // Get status color
    Color statusColor;
    IconData statusIcon;
    switch (selectedStatus) {
      case 'upcoming':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.schedule_rounded;
        break;
      case 'overdue':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.warning_rounded;
        break;
      case 'paid':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          // Count and label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${selectedStatus.substring(0, 1).toUpperCase()}${selectedStatus.substring(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Total amount',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Amount
          GestureDetector(
            onTap: isFormatted
                ? () {
                    AmountInfoBottomSheet.show(
                      context,
                      amount: amount,
                      billCount: count,
                      title: '$count $selectedStatus bills',
                      formattedAmount: formattedAmount,
                    );
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  if (isFormatted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList(List<Bill> filteredBills) {
    // Show loading indicator while bills are being loaded
    if (context.watch<BillProvider>().isLoading && filteredBills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF97316)),
        ),
      );
    }

    if (filteredBills.isEmpty) {
      // Get status-specific empty message
      String emptyTitle;
      String emptySubtitle;
      IconData emptyIcon;
      Color emptyColor;

      switch (selectedStatus) {
        case 'upcoming':
          emptyTitle = 'No upcoming bills';
          emptySubtitle = 'You\'re all caught up! Add a new bill to track.';
          emptyIcon = Icons.event_available_rounded;
          emptyColor = const Color(0xFF3B82F6);
          break;
        case 'overdue':
          emptyTitle = 'No overdue bills';
          emptySubtitle = 'Great job! All your bills are paid on time.';
          emptyIcon = Icons.celebration_rounded;
          emptyColor = const Color(0xFF10B981);
          break;
        case 'paid':
          emptyTitle = 'No paid bills yet';
          emptySubtitle = 'Mark bills as paid to see them here.';
          emptyIcon = Icons.receipt_long_rounded;
          emptyColor = const Color(0xFF10B981);
          break;
        default:
          emptyTitle = 'No bills found';
          emptySubtitle = 'Add a new bill to get started.';
          emptyIcon = Icons.receipt_long_rounded;
          emptyColor = Colors.grey;
      }

      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: emptyColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 40, color: emptyColor),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Bills now archive immediately when paid - no near archival warnings needed
    return Column(
      children: filteredBills.map((bill) {
        return ExpandableBillCard(
          bill: bill,
          compactAmounts: _compactAmounts,
          daysRemaining: null, // No longer showing days remaining
          onMarkPaid: () => _showMarkPaidConfirmation(bill),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, 'Home'),
            _buildNavItem(1, Icons.analytics_outlined, 'Analytics'),
            _buildAddNavItem(),
            _buildNavItem(2, Icons.calendar_today_outlined, 'Calendar'),
            _buildNavItem(3, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNavItem() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddBillScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF97316),
              Color(0xFFF97316),
            ], // orange-400 to orange-500
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFFED7AA,
              ).withOpacity(0.3), // orange-200 shadow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });

        // Handle navigation for different tabs
        if (index == 0) {
          // Home tab - pop back to home if on another screen
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 1) {
          // Analytics tab
          Navigator.pushNamed(context, '/analytics').then((_) {
            // Reset to home tab when returning
            if (mounted) {
              setState(() {
                _selectedTabIndex = 0;
              });
            }
          });
        } else if (index == 2) {
          // Calendar tab
          Navigator.pushNamed(context, '/calendar').then((_) {
            // Reset to home tab when returning
            if (mounted) {
              setState(() {
                _selectedTabIndex = 0;
              });
            }
          });
        } else if (index == 3) {
          // Settings tab
          Navigator.pushNamed(context, '/settings').then((_) {
            // Reset to home tab when returning
            if (mounted) {
              setState(() {
                _selectedTabIndex = 0;
              });
            }
          });
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
              style: AppTextStyles.navLabel(
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

  void _showMarkPaidConfirmation(Bill bill) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Mark as Paid',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mark as Paid?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark this bill as paid?',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
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
                      formatCurrencyFull(bill.amount),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markPaid(bill.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Mark as Paid',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markPaid(String billId) async {
    final billProvider = context.read<BillProvider>();
    await billProvider.markBillAsPaid(billId);

    if (mounted) {
      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bill marked as paid! Check the Paid tab.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                selectedStatus = 'paid';
              });
            },
          ),
        ),
      );
    }
  }
}
