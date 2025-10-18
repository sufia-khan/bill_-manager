import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../utils/formatters.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _activeTab = 'total';
  String _timePeriod = 'yearly'; // weekly, monthly, yearly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  // Calculate weekly data
  List<Map<String, dynamic>> _calculateWeeklyData(List<Bill> bills) {
    final now = DateTime.now();
    final weeklyData = <Map<String, dynamic>>[];

    for (int i = -4; i < 4; i++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 - (i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekLabel = 'Week ${i + 5}';

      final weekBills = bills.where((bill) {
        final dueDate = DateTime.parse('${bill.due}T00:00:00');
        return !dueDate.isBefore(weekStart) && !dueDate.isAfter(weekEnd);
      }).toList();

      weeklyData.add({
        'label': weekLabel,
        'total': weekBills.fold(0.0, (sum, bill) => sum + bill.amount),
        'paid': weekBills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'pending': weekBills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'overdue': weekBills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });
    }
    return weeklyData;
  }

  // Calculate monthly data
  List<Map<String, dynamic>> _calculateMonthlyData(List<Bill> bills) {
    final now = DateTime.now();
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

    for (int i = -6; i < 6; i++) {
      final month = DateTime(now.year, now.month + i, 1);
      final monthBills = bills.where((bill) {
        final dueDate = DateTime.parse('${bill.due}T00:00:00');
        return dueDate.year == month.year && dueDate.month == month.month;
      }).toList();

      monthlyData.add({
        'label': months[month.month - 1],
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

  // Calculate yearly data
  List<Map<String, dynamic>> _calculateYearlyData(List<Bill> bills) {
    final now = DateTime.now();
    final yearlyData = <Map<String, dynamic>>[];

    for (int i = -3; i < 3; i++) {
      final year = now.year + i;
      final yearBills = bills.where((bill) {
        final dueDate = DateTime.parse('${bill.due}T00:00:00');
        return dueDate.year == year;
      }).toList();

      yearlyData.add({
        'label': year.toString(),
        'total': yearBills.fold(0.0, (sum, bill) => sum + bill.amount),
        'paid': yearBills
            .where((b) => b.status == 'paid')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'pending': yearBills
            .where((b) => b.status == 'upcoming')
            .fold(0.0, (sum, bill) => sum + bill.amount),
        'overdue': yearBills
            .where((b) => b.status == 'overdue')
            .fold(0.0, (sum, bill) => sum + bill.amount),
      });
    }
    return yearlyData;
  }

  @override
  Widget build(BuildContext context) {
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

        final chartData = _timePeriod == 'weekly'
            ? _calculateWeeklyData(bills)
            : _timePeriod == 'yearly'
            ? _calculateYearlyData(bills)
            : _calculateMonthlyData(bills);

        return Scaffold(
          backgroundColor: Colors.white,
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
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart, color: Color(0xFFFF8C00), size: 24),
                SizedBox(width: 8),
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF8C00),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Weekly', 'Monthly', 'Yearly'].map((period) {
                      final isSelected = _timePeriod == period.toLowerCase();
                      return InkWell(
                        onTap: () =>
                            setState(() => _timePeriod = period.toLowerCase()),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8C00)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            period,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFFF8C00),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary Cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildSummaryCard(
                      'Total Bills',
                      const Color(0xFFFF8C00),
                      'total',
                      chartData,
                    ),
                    _buildSummaryCard(
                      'Paid',
                      const Color(0xFF34D399),
                      'paid',
                      chartData,
                    ),
                    _buildSummaryCard(
                      'Pending',
                      const Color(0xFFFACC15),
                      'pending',
                      chartData,
                    ),
                    _buildSummaryCard(
                      'Overdue',
                      const Color(0xFFEF4444),
                      'overdue',
                      chartData,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Chart
                _buildChart(chartData),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    Color color,
    String tab,
    List<Map<String, dynamic>> chartData,
  ) {
    final isActive = _activeTab == tab;
    // Calculate total from chart data for the selected time period
    final total = chartData.fold(
      0.0,
      (sum, data) => sum + ((data[tab] ?? 0) as num).toDouble(),
    );

    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrencyShort(total),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> chartData) {
    final colors = {
      'total': const Color(0xFFFF8C00),
      'paid': const Color(0xFF34D399),
      'pending': const Color(0xFFFACC15),
      'overdue': const Color(0xFFEF4444),
    };
    final activeColor = colors[_activeTab]!;
    final periodLabel = _timePeriod == 'weekly'
        ? 'Weekly'
        : _timePeriod == 'yearly'
        ? 'Yearly'
        : 'Monthly';
    final title =
        '${_activeTab == 'total' ? 'Total Bills' : _activeTab[0].toUpperCase() + _activeTab.substring(1)} ($periodLabel Overview)';

    double maxValue = 0;
    for (var data in chartData) {
      final value = (data[_activeTab] ?? 0).toDouble();
      if (value > maxValue) maxValue = value;
    }
    final dynamicMaxY = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 100.0;
    final interval = dynamicMaxY > 0 ? (dynamicMaxY / 5).ceilToDouble() : 20.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
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
                        if (index >= 0 && index < chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              chartData[index]['label'],
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
                      reservedSize: 45,
                      interval: interval,
                      getTitlesWidget: (value, meta) => Text(
                        '\${value.toInt()}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: dynamicMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData
                        .asMap()
                        .entries
                        .map(
                          (entry) => FlSpot(
                            entry.key.toDouble(),
                            (entry.value[_activeTab] ?? 0).toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: activeColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: activeColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: activeColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: BorderSide(color: Colors.grey.shade200),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      final label = chartData[spot.x.toInt()]['label'];
                      return LineTooltipItem(
                        '$label\n${formatCurrencyFull(spot.y)}',
                        TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
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
