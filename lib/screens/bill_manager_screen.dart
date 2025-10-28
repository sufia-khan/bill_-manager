import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                          Text('BillManager', style: AppTextStyles.appTitle()),
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
                    style: AppTextStyles.summaryTitle(),
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
                    style: AppTextStyles.amountMedium(),
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
              style: AppTextStyles.summarySubtitle(),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

    // Get color based on status
    Color tabColor;
    switch (status) {
      case 'upcoming':
        tabColor = const Color(0xFFFF8C00); // Orange
        break;
      case 'overdue':
        tabColor = const Color(0xFFEF4444); // Red
        break;
      case 'paid':
        tabColor = const Color(0xFF059669); // Green
        break;
      default:
        tabColor = const Color(0xFFFF8C00);
    }

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
              color: isSelected ? tabColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.tab(
            color: isSelected ? tabColor : Colors.grey.shade600,
            isSelected: isSelected,
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
          Text('$count $selectedStatus', style: AppTextStyles.filterCount()),
          const Spacer(),
          Text(formattedAmount, style: AppTextStyles.filterAmount()),
          if (isFormatted) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                AmountInfoBottomSheet.show(
                  context,
                  amount: amount,
                  billCount: count,
                  title: '$count $selectedStatus bills',
                  formattedAmount: formattedAmount,
                );
              },
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
            colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8C00).withOpacity(0.3),
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
                  ? const Color(0xFFFF8C00)
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.navLabel(
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
}
