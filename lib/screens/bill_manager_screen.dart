import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
// BillHive import removed (unused)
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_badge_provider.dart';
import '../widgets/animated_subtitle.dart';
import '../widgets/expandable_bill_card.dart';
import '../widgets/amount_info_bottom_sheet.dart';
import '../utils/formatters.dart';
import '../utils/text_styles.dart';
// BillStatusHelper removed (unused)
import '../services/trial_service.dart';
import 'add_bill_screen.dart';
import 'notification_screen.dart';
import 'subscription_screen.dart';

class BillManagerScreen extends StatefulWidget {
  final String? initialStatus; // 'upcoming', 'overdue', 'paid'
  final String? highlightBillId; // Bill ID to highlight for 2 seconds

  const BillManagerScreen({
    super.key,
    this.initialStatus,
    this.highlightBillId,
  });

  @override
  State<BillManagerScreen> createState() => _BillManagerScreenState();
}

class _BillManagerScreenState extends State<BillManagerScreen>
    with WidgetsBindingObserver {
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

  // Timer for periodic recurring bill check (for 1-minute testing)
  Timer? _recurringBillTimer;

  // Highlight state for bill card
  String? _highlightedBillId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set initial status if provided (e.g., from notification click)
    if (widget.initialStatus != null) {
      selectedStatus = widget.initialStatus!;
    }

    // Load bills when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();

      // Start periodic timer to check recurring bills every 30 seconds
      // This is needed for 1-minute recurring bills testing
      _startRecurringBillTimer();

      // Highlight bill if provided (from notification click)
      if (widget.highlightBillId != null) {
        setState(() {
          _highlightedBillId = widget.highlightBillId;
        });
        // Clear highlight after 2 seconds
        _highlightTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _highlightedBillId = null;
            });
          }
        });
      }
    });
  }

  void _startRecurringBillTimer() {
    _recurringBillTimer?.cancel();
    // Check every 15 seconds for 1-minute testing mode
    _recurringBillTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        context.read<BillProvider>().runRecurringBillMaintenance();
      }
    });
  }

  @override
  void dispose() {
    _recurringBillTimer?.cancel();
    _highlightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes to foreground, check for overdue recurring bills
    if (state == AppLifecycleState.resumed) {
      context.read<BillProvider>().checkOverdueRecurringBills();
    }
  }

  // Totals are now calculated in BillProvider

  @override
  Widget build(BuildContext context) {
    // Listen to currency changes to rebuild UI
    context.watch<CurrencyProvider>();

    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        // Optimizing: Use pre-processed lists from Provider
        List<Bill> statusBills;
        switch (selectedStatus) {
          case 'upcoming':
            statusBills = billProvider.upcomingBills;
            break;
          case 'overdue':
            statusBills = billProvider.overdueBills;
            break;
          case 'paid':
            statusBills = billProvider.paidBills;
            break;
          default:
            statusBills = billProvider.upcomingBills;
        }

        // Filter by category (fast operation on smaller list)
        final filteredBills = selectedCategory == 'All'
            ? statusBills
            : statusBills.where((b) => b.category == selectedCategory).toList();

        final filteredCount = filteredBills.length;
        final filteredAmount = filteredBills.fold(
          0.0,
          (sum, bill) => sum + bill.amount,
        );

        // Get pre-calculated totals from provider
        final thisMonthTotal = billProvider.totalUpcomingThisMonth;
        final thisMonthCount = billProvider.countUpcomingThisMonth;
        final next7DaysTotal = billProvider.totalUpcomingNext7Days;
        final next7DaysCount = billProvider.countUpcomingNext7Days;

        // Use allProcessedBills for the "all bills" argument if needed,
        // though it seems unused in _buildScaffold based on analysis
        final allBills = billProvider.allProcessedBills;

        return _buildScaffold(
          context,
          allBills,
          filteredBills,
          thisMonthTotal,
          thisMonthCount,
          next7DaysTotal,
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
                          // Unread notification badge - uses provider for real-time updates
                          Consumer<NotificationBadgeProvider>(
                            builder: (context, badgeProvider, _) {
                              if (badgeProvider.unreadCount > 0) {
                                return Positioned(
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
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Free tier bill limit indicator
                if (!TrialService.canAccessProFeatures())
                  Consumer<BillProvider>(
                    builder: (context, billProvider, child) {
                      final remainingBills = billProvider
                          .getRemainingFreeTierBills();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFF5E6),
                              const Color(0xFFFFE5CC).withValues(alpha: 0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFE5CC),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can add $remainingBills more bill${remainingBills != 1 ? 's' : ''} (${TrialService.freeMaxBills} max on free plan)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SubscriptionScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'This ${DateFormat('MMM').format(DateTime.now())}',
                        thisMonthTotal,
                        '$thisMonthCount bill${thisMonthCount != 1 ? 's' : ''} due',
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        thisMonthCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Next 7 days',
                        next7DaysTotal,
                        '$next7DaysCount upcoming bill${next7DaysCount != 1 ? 's' : ''}',
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
    // Check if amount is formatted (shortened) - only >= 1000 gets shortened
    final isFormatted = amount >= 1000;

    final cardContent = AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: title != 'Next 7 days'
                ? [
                    const Color(0xFFFED7AA), // orange-100
                    const Color(0xFFFDE68A), // amber-100
                    const Color(0xFFFEF08A), // yellow-100
                  ]
                : [
                    const Color(0xFFDBEAFE), // blue-100
                    const Color(0xFFE0F2FE), // sky-100
                    const Color(0xFFCFFAFE), // cyan-100
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: title != 'Next 7 days'
                ? const Color(0xFFFED7AA).withValues(alpha: 0.6) // orange-200
                : const Color(0xFFBFDBFE).withValues(alpha: 0.6), // blue-200
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (title != 'Next 7 days'
                          ? const Color(0xFFFB923C) // orange-400
                          : const Color(0xFF3B82F6)) // blue-500
                      .withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: title != 'Next 7 days'
                          ? [
                              const Color(0xFFFB923C), // orange-400
                              const Color(0xFFF97316), // orange-500
                            ]
                          : [
                              const Color(0xFF60A5FA), // blue-400
                              const Color(0xFF3B82F6), // blue-500
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (title != 'Next 7 days'
                                    ? const Color(0xFFFB923C) // orange-400
                                    : const Color(0xFF60A5FA)) // blue-400
                                .withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: icon,
                ),
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: title != 'Next 7 days'
                          ? const Color(0xFFC2410C) // orange-700
                          : const Color(0xFF1D4ED8), // blue-700
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatCurrencyShort(amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B), // slate-800
                    height: 1.1,
                  ),
                ),
                // Only show info icon when amount is formatted (shortened)
                if (isFormatted) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: title != 'Next 7 days'
                        ? const Color(0xFFC2410C) // orange-700
                        : const Color(0xFF1D4ED8), // blue-700
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155), // slate-700
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );

    // Only make tappable when amount is formatted
    if (isFormatted) {
      return GestureDetector(
        onTap: () {
          AmountInfoBottomSheet.show(
            context,
            amount: amount,
            billCount: billCount,
            title: title,
          );
        },
        child: cardContent,
      );
    }

    return cardContent;
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
        final isHighlighted = _highlightedBillId == bill.id;
        return ExpandableBillCard(
          bill: bill,
          compactAmounts: _compactAmounts,
          daysRemaining: null, // No longer showing days remaining
          onMarkPaid: () => _showMarkPaidConfirmation(bill),
          isHighlighted: isHighlighted,
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
            _buildNavItem(0, Icons.home_outlined, 'Home', isPro: false),
            _buildNavItem(
              1,
              Icons.analytics_outlined,
              'Analytics',
              isPro: true,
            ),
            _buildAddNavItem(),
            _buildNavItem(
              2,
              Icons.calendar_today_outlined,
              'Calendar',
              isPro: true,
            ),
            _buildNavItem(3, Icons.settings_outlined, 'Settings', isPro: false),
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

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool isPro = false,
  }) {
    final isSelected = _selectedTabIndex == index;
    final hasProAccess = TrialService.canAccessProFeatures();
    final showProBadge = isPro && !hasProAccess;

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
          // Analytics tab - Pro feature
          if (!TrialService.canAccessProFeatures()) {
            _showProFeatureDialog('Advanced Analytics');
            setState(() {
              _selectedTabIndex = 0;
            });
            return;
          }
          Navigator.pushNamed(context, '/analytics').then((_) {
            // Reset to home tab when returning
            if (mounted) {
              setState(() {
                _selectedTabIndex = 0;
              });
            }
          });
        } else if (index == 2) {
          // Calendar tab - Pro feature
          if (!TrialService.canAccessProFeatures()) {
            _showProFeatureDialog('Calendar View');
            setState(() {
              _selectedTabIndex = 0;
            });
            return;
          }
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : Colors.grey.shade600,
                ),
                if (showProBadge)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
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

  void _showProFeatureDialog(String featureName) {
    final featureDetails = _getFeatureDetails(featureName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                featureDetails['icon'] as IconData,
                color: const Color(0xFFD4AF37),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                featureName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE5CC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_open,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            featureDetails['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      featureDetails['description'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                TrialService.getMembershipStatus() == MembershipStatus.free
                    ? 'Your free trial has ended. Upgrade to Pro to unlock all features.'
                    : 'Upgrade to Pro to unlock all premium features.',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Other Pro Features:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              ...TrialService.getProFeaturesList()
                  .where((f) => f['title'] != featureDetails['title'])
                  .take(4)
                  .map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFD4AF37),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature['title'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFeatureDetails(String featureName) {
    switch (featureName) {
      case 'Advanced Analytics':
        return {
          'icon': Icons.analytics,
          'title': 'Advanced Analytics & Insights',
          'description':
              'Get detailed insights into your spending patterns with interactive charts, category breakdowns, monthly trends, and spending forecasts. Make smarter financial decisions with data-driven insights.',
        };
      case 'Calendar View':
        return {
          'icon': Icons.calendar_month,
          'title': 'Calendar View',
          'description':
              'Visualize all your bills in a beautiful calendar layout. See upcoming bills, due dates, and payment history at a glance. Never miss a payment with the calendar overview.',
        };
      default:
        return {
          'icon': Icons.workspace_premium,
          'title': 'Pro Feature',
          'description':
              'This is a premium feature available only to Pro subscribers. Upgrade to unlock all Pro features.',
        };
    }
  }
}
