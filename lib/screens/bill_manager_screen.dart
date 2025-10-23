import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/animated_subtitle.dart';
import '../widgets/expandable_bill_card.dart';
import '../utils/formatters.dart';
import 'add_bill_screen.dart';
import 'notification_screen.dart';

class BillManagerScreen extends StatefulWidget {
  const BillManagerScreen({super.key});

  @override
  State<BillManagerScreen> createState() => _BillManagerScreenState();
}

class _BillManagerScreenState extends State<BillManagerScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabRotationAnimation;

  // Bills are now loaded from BillProvider - no hardcoded data!

  // Category data with icons
  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Rent', 'icon': Icons.home},
    {'name': 'Utilities', 'icon': Icons.electrical_services},
    {'name': 'Electricity', 'icon': Icons.bolt},
    {'name': 'Water', 'icon': Icons.water_drop},
    {'name': 'Gas', 'icon': Icons.local_fire_department},
    {'name': 'Internet', 'icon': Icons.wifi},
    {'name': 'Phone', 'icon': Icons.phone},
    {'name': 'Subscriptions', 'icon': Icons.card_membership},
    {'name': 'Streaming', 'icon': Icons.tv},
    {'name': 'Groceries', 'icon': Icons.shopping_cart},
    {'name': 'Transport', 'icon': Icons.directions_bus},
    {'name': 'Fuel', 'icon': Icons.local_gas_station},
    {'name': 'Insurance', 'icon': Icons.security},
    {'name': 'Health', 'icon': Icons.local_hospital},
    {'name': 'Medical', 'icon': Icons.medical_services},
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Entertainment', 'icon': Icons.movie},
    {'name': 'Credit Card', 'icon': Icons.credit_card},
    {'name': 'Loan', 'icon': Icons.account_balance},
    {'name': 'Taxes', 'icon': Icons.receipt},
    {'name': 'Savings', 'icon': Icons.savings},
    {'name': 'Donations', 'icon': Icons.volunteer_activism},
    {'name': 'Home Maintenance', 'icon': Icons.home_repair_service},
    {'name': 'HOA', 'icon': Icons.apartment},
    {'name': 'Gym', 'icon': Icons.fitness_center},
    {'name': 'Childcare', 'icon': Icons.child_care},
    {'name': 'Pets', 'icon': Icons.pets},
    {'name': 'Travel', 'icon': Icons.flight},
    {'name': 'Parking', 'icon': Icons.local_parking},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];

  String selectedCategory = 'All';
  String selectedStatus = 'upcoming'; // upcoming, overdue, paid
  int _selectedTabIndex = 0;
  bool _compactAmounts = true;
  final bool _showSettings = false;

  @override
  void initState() {
    super.initState();

    // Initialize FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    _fabRotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Load bills when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
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
      floatingActionButton: _buildAddButton(),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                          const Text(
                            'BillManager',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF8C00),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const AnimatedSubtitle(),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF8C00,
                            ).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Color(0xFFFF8C00),
                          size: 24,
                        ),
                        tooltip: 'Notifications',
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
                        '$thisMonthCount upcoming bill${thisMonthCount != 1 ? 's' : ''}',
                        const Icon(
                          Icons.attach_money,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Next 7 days',
                        next7DaysTotal,
                        '$next7DaysCount upcoming bill${next7DaysCount != 1 ? 's' : ''}',
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showSettings) _buildSettingsSection(),
              _buildFilterSection(),
              const SizedBox(height: 16),
              _buildFilteredSection(filteredCount, filteredAmount),
              const SizedBox(height: 12),
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
                  0xFFFF8C00,
                ).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFFFF8C00),
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
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
            blurRadius: 8,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrencyFull(amount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatusTab('upcoming', 'Upcoming')),
          Expanded(child: _buildStatusTab('overdue', 'Overdue')),
          Expanded(child: _buildStatusTab('paid', 'Paid')),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label) {
    final isSelected = selectedStatus == status;

    return InkWell(
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFFF8C00) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredSection(int count, double amount) {
    final formattedAmount = _compactAmounts
        ? formatCurrencyShort(amount)
        : formatCurrencyFull(amount);
    final fullAmount = formatCurrencyFull(amount);
    final isFormatted = formattedAmount != fullAmount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            color: const Color(0xFFFF8C00),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                children: [
                  TextSpan(
                    text: '$count ${selectedStatus}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' • ',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  TextSpan(
                    text: formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFormatted)
            GestureDetector(
              onTap: () => _showAmountBottomSheet(amount),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
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
      ),
    );
  }

  Widget _buildBillsList(List<Bill> filteredBills) {
    // Show loading indicator while bills are being loaded
    if (context.watch<BillProvider>().isLoading && filteredBills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );
    }

    if (filteredBills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'No bills match this filter.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adding a new bill or change the category.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
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
        // Don't navigate if already on home screen
        if (index == 0) return;

        setState(() {
          _selectedTabIndex = index;
        });

        // Handle navigation for different tabs
        if (index == 1) {
          // Analytics tab
          Navigator.pushNamed(context, '/analytics');
        } else if (index == 2) {
          // Calendar tab
          Navigator.pushNamed(context, '/calendar');
        } else if (index == 3) {
          // Settings tab
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
                  ? const Color(0xFFFF8C00)
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFFFF8C00)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabScaleAnimation.value,
          child: Transform.rotate(
            angle: _fabRotationAnimation.value,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBillScreen(),
                  ),
                );
              },
              elevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF8C00), const Color(0xFFFF6B00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated background pattern
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Subtle border
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Inner shadow effect
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    // Main icon with enhanced styling
                    Container(
                      padding: const EdgeInsets.all(2),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow effect behind icon
                          Icon(
                            Icons.add,
                            size: 32,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          // Main icon
                          const Icon(
                            Icons.add,
                            size: 28,
                            color: Colors.white,
                            weight: 700,
                          ),
                        ],
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
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFFFF8C00),
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
                backgroundColor: const Color(0xFFFF8C00),
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

  void _showAmountBottomSheet(double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Compact amount (First - highlighted)
              Text(
                formatCurrencyShort(amount),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8C00),
                ),
              ),
              const SizedBox(height: 16),
              // Full amount (Second - below)
              Text(
                formatCurrencyFull(amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
