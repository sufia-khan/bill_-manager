import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../utils/formatters.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1;
  String _selectedFilter = 'all';
  int _monthOffset = 0;
  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize chart animation controller
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Start animation
    _chartAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  // Trigger animation when filter changes
  void _changeFilter(String newFilter) {
    if (_selectedFilter != newFilter) {
      setState(() {
        _selectedFilter = newFilter;
        _monthOffset = 0;
      });

      // Restart animation for smooth transition
      _chartAnimationController.reset();
      _chartAnimationController.forward();
    }
  }

  // Calculate data starting from first bill month
  Map<String, List<Map<String, dynamic>>> _calculateAllData(List<Bill> bills) {
    if (bills.isEmpty) {
      return {'all': [], 'paid': [], 'upcoming': [], 'overdue': []};
    }

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

    // Find earliest and latest bill dates
    DateTime? earliestDate;
    DateTime? latestDate;

    for (var bill in bills) {
      final dueDate = DateTime.parse('${bill.due}T00:00:00');
      if (earliestDate == null || dueDate.isBefore(earliestDate))
        earliestDate = dueDate;
      if (latestDate == null || dueDate.isAfter(latestDate))
        latestDate = dueDate;
    }

    if (earliestDate == null || latestDate == null) {
      return {'all': [], 'paid': [], 'upcoming': [], 'overdue': []};
    }

    // Start from earliest month, go to latest month + 6 months
    final startMonth = DateTime(earliestDate.year, earliestDate.month, 1);
    final endMonth = DateTime(latestDate.year, latestDate.month + 6, 1);

    final allData = <Map<String, dynamic>>[];
    final paidData = <Map<String, dynamic>>[];
    final upcomingData = <Map<String, dynamic>>[];
    final overdueData = <Map<String, dynamic>>[];

    var currentMonth = startMonth;
    while (currentMonth.isBefore(endMonth) ||
        currentMonth.isAtSameMomentAs(endMonth)) {
      final monthBills = bills.where((bill) {
        final dueDate = DateTime.parse('${bill.due}T00:00:00');
        return dueDate.year == currentMonth.year &&
            dueDate.month == currentMonth.month;
      }).toList();

      final monthLabel = months[currentMonth.month - 1];

      allData.add({
        'month': monthLabel,
        'amount': monthBills.fold(0.0, (sum, bill) => sum + bill.amount),
      });
      paidData.add({
        'month': monthLabel,
        'amount': monthBills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });
      upcomingData.add({
        'month': monthLabel,
        'amount': monthBills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });
      overdueData.add({
        'month': monthLabel,
        'amount': monthBills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return {
      'all': allData,
      'paid': paidData,
      'upcoming': upcomingData,
      'overdue': overdueData,
    };
  }

  // Calculate top categories
  List<Map<String, dynamic>> _calculateTopCategories(List<Bill> bills) {
    final categoryTotals = <String, double>{};
    for (var bill in bills) {
      categoryTotals[bill.category] =
          (categoryTotals[bill.category] ?? 0) + bill.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedCategories
        .take(5)
        .map((entry) => {'name': entry.key, 'amount': entry.value})
        .toList();
  }

  Map<String, Map<String, dynamic>> _calculateStats(List<Bill> bills) {
    return {
      'all': {
        'count': bills.length,
        'total': bills.fold(0.0, (sum, bill) => sum + bill.amount),
      },
      'paid': {
        'count': bills.where((b) => b.status == 'paid').length,
        'total': bills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      },
      'upcoming': {
        'count': bills.where((b) => b.status == 'upcoming').length,
        'total': bills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      },
      'overdue': {
        'count': bills.where((b) => b.status == 'overdue').length,
        'total': bills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      },
    };
  }

  List<Map<String, dynamic>> _getVisibleData(
    Map<String, List<Map<String, dynamic>>> allData,
  ) {
    final data = allData[_selectedFilter]!;
    if (data.isEmpty) return [];
    final endIndex = (_monthOffset + 6).clamp(0, data.length);
    return data.sublist(_monthOffset, endIndex);
  }

  bool _canGoForward(Map<String, List<Map<String, dynamic>>> allData) =>
      _monthOffset + 6 < allData[_selectedFilter]!.length;
  bool _canGoBack() => _monthOffset > 0;

  Color _getLineColor() {
    switch (_selectedFilter) {
      case 'paid':
        return const Color(0xFF10B981);
      case 'upcoming':
        return const Color(0xFF3B82F6);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFFF8C00);
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
        setState(() => _selectedTabIndex = index);
        if (index == 0)
          Navigator.pop(context);
        else if (index == 2)
          Navigator.pushNamed(context, '/calendar');
        else if (index == 3)
          Navigator.pushNamed(context, '/settings');
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

  @override
  Widget build(BuildContext context) {
    // Listen to currency changes to rebuild UI
    context.watch<CurrencyProvider>();

    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        final bills = billProvider.bills
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

        final allData = _calculateAllData(bills);
        final stats = _calculateStats(bills);
        final visibleData = _getVisibleData(allData);
        final topCategories = _calculateTopCategories(bills);

        return Scaffold(
          backgroundColor: const Color(0xFFFFF9F0),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFFF8C00),
                size: 20,
              ),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Your spending insights',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF8C00),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildFilterCard(
                      'all',
                      'All Bills',
                      Icons.check_circle,
                      stats['all']!,
                      const Color(0xFFFF8C00),
                    ),
                    _buildFilterCard(
                      'paid',
                      'Paid',
                      Icons.check_circle,
                      stats['paid']!,
                      const Color(0xFF10B981),
                    ),
                    _buildFilterCard(
                      'upcoming',
                      'Upcoming',
                      Icons.access_time,
                      stats['upcoming']!,
                      const Color(0xFF3B82F6),
                    ),
                    _buildFilterCard(
                      'overdue',
                      'Overdue',
                      Icons.error,
                      stats['overdue']!,
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLineChart(visibleData, allData),
                const SizedBox(height: 24),
                if (topCategories.isNotEmpty)
                  _buildTopCategoriesChart(topCategories),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterCard(
    String filter,
    String title,
    IconData icon,
    Map<String, dynamic> stat,
    Color color,
  ) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => _changeFilter(filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : const Color(0xFFFF8C00).withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${stat['count']}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrencyShort(stat['total']),
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(
    List<Map<String, dynamic>> visibleData,
    Map<String, List<Map<String, dynamic>>> allData,
  ) {
    final lineColor = _getLineColor();
    final filterName =
        _selectedFilter[0].toUpperCase() + _selectedFilter.substring(1);

    // Check if there's any data
    final hasData = visibleData.any((data) => (data['amount'] as double) > 0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_selectedFilter),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$filterName Bills Trend',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _canGoBack()
                          ? () => setState(
                              () => _monthOffset = (_monthOffset - 6).clamp(
                                0,
                                allData[_selectedFilter]!.length,
                              ),
                            )
                          : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: _canGoBack()
                            ? const Color(0xFFFF8C00)
                            : Colors.grey.shade300,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _canGoBack()
                            ? const Color(0xFFFF8C00).withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _canGoForward(allData)
                          ? () => setState(() => _monthOffset += 6)
                          : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: _canGoForward(allData)
                            ? const Color(0xFFFF8C00)
                            : Colors.grey.shade300,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _canGoForward(allData)
                            ? const Color(0xFFFF8C00).withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            hasData
                ? SizedBox(
                    height: 280,
                    child: AnimatedBuilder(
                      animation: _chartAnimation,
                      builder: (context, child) {
                        return LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
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
                                    if (index >= 0 &&
                                        index < visibleData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          visibleData[index]['month'],
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
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
                                  reservedSize: 55,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0)
                                      return const SizedBox.shrink();

                                    // Calculate max value to determine proper intervals
                                    final maxValue = visibleData.fold<double>(
                                      0,
                                      (max, data) =>
                                          (data['amount'] as double) > max
                                          ? data['amount'] as double
                                          : max,
                                    );

                                    // Calculate interval (show only 4 labels to prevent overlap)
                                    final interval = maxValue / 4;

                                    // Only show labels at proper intervals
                                    if (value < interval * 0.8)
                                      return const SizedBox.shrink();

                                    // Check if this value is close to an interval point
                                    final remainder = value % interval;
                                    if (remainder > interval * 0.2 &&
                                        remainder < interval * 0.8) {
                                      return const SizedBox.shrink();
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        formatCurrencyShort(value),
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 9,
                                        ),
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minY: 0,
                            lineBarsData: [
                              LineChartBarData(
                                spots: visibleData
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => FlSpot(
                                        entry.key.toDouble(),
                                        entry.value['amount'] *
                                            _chartAnimation.value,
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Color.lerp(
                                  Colors.grey.shade300,
                                  lineColor,
                                  _chartAnimation.value,
                                )!,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                preventCurveOverShooting: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) =>
                                          FlDotCirclePainter(
                                            radius: 6 * _chartAnimation.value,
                                            color: lineColor,
                                            strokeWidth: 2,
                                            strokeColor: Colors.white,
                                          ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color.lerp(
                                        Colors.grey.shade100,
                                        lineColor,
                                        _chartAnimation.value,
                                      )!.withValues(
                                        alpha: 0.3 * _chartAnimation.value,
                                      ),
                                      Color.lerp(
                                        Colors.grey.shade100,
                                        lineColor,
                                        _chartAnimation.value,
                                      )!.withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (spot) =>
                                    const Color(0xFF1F2937),
                                tooltipRoundedRadius: 8,
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                getTooltipItems: (touchedSpots) => touchedSpots
                                    .map(
                                      (spot) => LineTooltipItem(
                                        formatCurrencyFull(spot.y),
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    height: 280,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter == 'all' ? '' : _selectedFilter} bills',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFilter == 'overdue'
                              ? 'Great! You have no overdue bills'
                              : 'No data available for this period',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoriesChart(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final maxAmount = categories.first['amount'] as double;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map((category) {
            final percentage = (category['amount'] as double) / maxAmount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category['name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      Text(
                        formatCurrencyShort(category['amount']),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF8C00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(
                          const Color(0xFFFF8C00),
                          const Color(0xFFFFA94D),
                          1 - percentage,
                        )!,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
