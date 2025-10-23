import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill_hive.dart';
import '../utils/formatters.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentDate;
  late int _selectedDay;
  int _selectedTabIndex = 2;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, 1);
    _selectedDay = now.day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday % 7;
  }

  List<BillHive> _getBillsForDate(int day, List<BillHive> bills) {
    final targetDate = DateTime(_currentDate.year, _currentDate.month, day);
    return bills.where((bill) {
      return bill.dueAt.year == targetDate.year &&
          bill.dueAt.month == targetDate.month &&
          bill.dueAt.day == targetDate.day;
    }).toList();
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        day == now.day;
  }

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    });
  }

  String _getBillStatus(BillHive bill) {
    if (bill.isPaid) return 'paid';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(bill.dueAt.year, bill.dueAt.month, bill.dueAt.day);
    if (dueDate.isBefore(today)) return 'overdue';
    return 'upcoming';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF10B981); // Green
      case 'overdue':
        return const Color(0xFFEF4444); // Red
      case 'upcoming':
        return const Color(0xFF3B82F6); // Blue
      default:
        return Colors.grey;
    }
  }

  void _showAmountBottomSheet(
    BuildContext context,
    double amount,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Amount',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: subtextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF334155)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Amount',
                      style: TextStyle(fontSize: 13, color: subtextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(amount),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(
    bool isDarkMode,
    Color primaryColor,
    Color cardColor,
    Color subtextColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? const Color(0xFF334155) : Colors.grey.shade100,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              0,
              Icons.home_outlined,
              'Home',
              primaryColor,
              subtextColor,
            ),
            _buildNavItem(
              1,
              Icons.analytics_outlined,
              'Analytics',
              primaryColor,
              subtextColor,
            ),
            _buildNavItem(
              2,
              Icons.calendar_today_outlined,
              'Calendar',
              primaryColor,
              subtextColor,
            ),
            _buildNavItem(
              3,
              Icons.settings_outlined,
              'Settings',
              primaryColor,
              subtextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color primaryColor,
    Color subtextColor,
  ) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        // Don't navigate if already on calendar screen
        if (index == 2) return;

        setState(() {
          _selectedTabIndex = index;
        });

        if (index == 0) {
          // Home tab - pop back to root
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 1) {
          // Analytics tab
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.pushNamed(context, '/analytics');
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
              color: isSelected ? primaryColor : subtextColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? primaryColor : subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final primaryColor = isDarkMode
        ? const Color(0xFF6366F1)
        : const Color(0xFFFF8C00);
    final backgroundColor = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF3F4F6);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1F2937);
    final subtextColor = isDarkMode
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);

    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        final bills = billProvider.bills;
        final daysInMonth = _getDaysInMonth(_currentDate);
        final firstDay = _getFirstDayOfMonth(_currentDate);
        final monthNames = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        final calendarDays = <int?>[];
        for (int i = 0; i < firstDay; i++) {
          calendarDays.add(null);
        }
        for (int day = 1; day <= daysInMonth; day++) {
          calendarDays.add(day);
        }

        final selectedBills = _getBillsForDate(_selectedDay, bills);

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Calendar',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(
            isDarkMode,
            primaryColor,
            cardColor,
            subtextColor,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 900;

              if (isWideScreen) {
                // Two column layout for wide screens
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar (2/3 width)
                      Expanded(
                        flex: 2,
                        child: _buildCalendarCard(
                          cardColor,
                          textColor,
                          subtextColor,
                          primaryColor,
                          isDarkMode,
                          monthNames,
                          dayNames,
                          calendarDays,
                          bills,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bills List (1/3 width)
                      Expanded(
                        flex: 1,
                        child: _buildBillsList(
                          selectedBills,
                          cardColor,
                          textColor,
                          subtextColor,
                          isDarkMode,
                          monthNames,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Single column layout for mobile - Everything scrollable
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Calendar Card
                      _buildCalendarCard(
                        cardColor,
                        textColor,
                        subtextColor,
                        primaryColor,
                        isDarkMode,
                        monthNames,
                        dayNames,
                        calendarDays,
                        bills,
                      ),
                      const SizedBox(height: 16),
                      // Bills Section
                      _buildBillsList(
                        selectedBills,
                        cardColor,
                        textColor,
                        subtextColor,
                        isDarkMode,
                        monthNames,
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard(
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color primaryColor,
    bool isDarkMode,
    List<String> monthNames,
    List<String> dayNames,
    List<int?> calendarDays,
    List<BillHive> bills,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00), // Orange background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${monthNames[_curren
                  style: const (
                    fontSize: 22,
                    fontWeight: FontWe700,
                  
                ,
                  ,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    usMonth,
                    icon: const Icon(Icons.ze: 20),
                    style: IcleFrom(
                      backgroundColor: Col
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  
                tton(
              tMonth,
            ,
                    style: IconButton

                      paddin
              
                      tapTargetSize: MaterrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),shSize.TargetialTapze(36, 36),const SiumSize:        minim ),ll(8dgeInsets.at Eg: cons.2),: 0s(alphaithValuehite.wlors.wColor: Coound     backgr                 eFrom(.styl: 20)white, sizelor: Colors.ght, coevron_ri.chcons Icon(I icon: const       
          const SizedBox(height: 24),

          // Weekday Headers
          Row(
            children: dayNames.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: calendarDays.length,
            itemBuilder: (context, index) {
              final day = calendarDays[index];
              if (day == null) {
                return const SizedBox.shrink();
              }

              final dayBills = _getBillsForDate(day, bills);
              final isToday = _isToday(day);
              final isSelected = _selectedDay == day;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          )
                        : isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFFFF8C00)
                                : Colors.white,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      if (dayBills.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8C00)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList(
    List<BillHive> selectedBills,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
    List<String> monthNames,
  ) {
    // Calculate status counts
    final overdueCount = selectedBills
        .where((bill) => _getBillStatus(bill) == 'overdue')
        .length;
    final upcomingCount = selectedBills
        .where((bill) => _getBillStatus(bill) == 'upcoming')
        .length;
    final paidCount = selectedBills
        .where((bill) => _getBillStatus(bill) == 'paid')
        .length;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Text(
            '$_selectedDay ${monthNames[_currentDate.month - 1]} ${_currentDate.year}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (selectedBills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (overdueCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Overdue $overdueCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (upcomingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Upcoming $upcomingCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (paidCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Paid $paidCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Bills List
          if (selectedBills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: subtextColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No bills for this date',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...selectedBills.asMap().entries.map((entry) {
              final index = entry.key;
              final bill = entry.value;
              final status = _getBillStatus(bill);
              final statusColor = _getStatusColor(status);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < selectedBills.length - 1 ? 12 : 0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF334155)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bill.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                formatCurrencyShort(bill.amount),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  _showAmountBottomSheet(
                                    context,
                                    bill.amount,
                                    cardColor,
                                    textColor,
                                    subtextColor,
                                    isDarkMode,
                                  );
                                },
                                child: Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF475569)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bill.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
