import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/formatters.dart';
import '../models/bill.dart';
import '../widgets/animated_subtitle.dart';
import 'add_bill_screen.dart';
import 'bill_manager_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedTabIndex = 1;

  List<Bill> bills = [
    Bill(
      id: '1',
      title: 'Electricity',
      vendor: 'PowerCo',
      amount: 85.5,
      due: '2025-10-20',
      repeat: 'monthly',
      category: 'Utilities',
      status: 'upcoming',
    ),
    Bill(
      id: '2',
      title: 'Spotify',
      vendor: 'Spotify',
      amount: 9.99,
      due: '2025-10-18',
      repeat: 'monthly',
      category: 'Subscriptions',
      status: 'upcoming',
    ),
    Bill(
      id: '3',
      title: 'Rent',
      vendor: 'Landlord',
      amount: 1200.0,
      due: '2025-11-01',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
    Bill(
      id: '4',
      title: 'Internet',
      vendor: 'ISP',
      amount: 50.0,
      due: '2025-10-14',
      repeat: 'monthly',
      category: 'Utilities',
      status: 'overdue',
    ),
    Bill(
      id: '5',
      title: 'Apartment Rent',
      vendor: 'Landlord',
      amount: 345.0,
      due: '2025-10-25',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
    Bill(
      id: '6',
      title: 'Storage Rent',
      vendor: 'StorageCo',
      amount: 345.0,
      due: '2025-10-28',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
  ];

  double _getThisMonthTotal() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return bills
        .where((bill) => bill.due.startsWith(currentMonth))
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  double _getNext7DaysTotal() {
    final now = DateTime.now();
    final endOf7Days = now.add(const Duration(days: 7));

    return bills
        .where((bill) {
          final dueDate = DateTime.parse('${bill.due}T00:00:00');
          return dueDate.isAfter(now) && dueDate.isBefore(endOf7Days);
        })
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
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
        setState(() {
          _selectedTabIndex = index;
        });

        // Handle navigation for different tabs
        if (index == 0) { // Home tab
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const BillManagerScreen(),
            ),
            (route) => false,
          );
        } else if (index == 2) { // Calendar tab
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const CalendarScreen(),
            ),
            (route) => false,
          );
        } else if (index == 3) { // Settings tab
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
            (route) => false,
          );
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
              color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _activeTab = 'total';

  // Monthly data structure with all bill statuses
  final List<Map<String, dynamic>> monthlyData = const [
    {'month': 'Jan', 'total': 500, 'paid': 250, 'pending': 180, 'overdue': 70},
    {'month': 'Feb', 'total': 650, 'paid': 320, 'pending': 250, 'overdue': 80},
    {'month': 'Mar', 'total': 580, 'paid': 300, 'pending': 220, 'overdue': 60},
    {'month': 'Apr', 'total': 720, 'paid': 390, 'pending': 280, 'overdue': 50},
    {'month': 'May', 'total': 850, 'paid': 450, 'pending': 320, 'overdue': 80},
    {'month': 'Jun', 'total': 900, 'paid': 480, 'pending': 350, 'overdue': 70},
  ];

  @override
  Widget build(BuildContext context) {
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
            color: Color(0xFFFF8C00),
            size: 20,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Track your spending and bill trends',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 280,
              child: _buildSummaryCards(),
            ),
            const SizedBox(height: 32),
            _buildBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildSummaryCard(
          tab: 'total',
          color: const Color(0xFFFF8C00),
          icon: Icons.attach_money,
          title: 'Total Bills',
          amount: formatCurrencyFull(2300),
        ),
        _buildSummaryCard(
          tab: 'paid',
          color: const Color(0xFF059669),
          icon: Icons.check_circle,
          title: 'Paid Bills',
          amount: formatCurrencyFull(1900),
        ),
        _buildSummaryCard(
          tab: 'pending',
          color: const Color(0xFFD97706),
          icon: Icons.pending,
          title: 'Pending Bills',
          amount: formatCurrencyFull(400),
        ),
        _buildSummaryCard(
          tab: 'overdue',
          color: const Color(0xFFDC2626),
          icon: Icons.warning,
          title: 'Overdue Bills',
          amount: formatCurrencyFull(150),
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
  }) {
    final isActive = _activeTab == tab;

    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade100,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.03),
              blurRadius: isActive ? 15 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? color : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isActive ? Colors.white : color, size: 20),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive ? color : Colors.grey.shade600,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isActive ? color : color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildBarChart() {
    Color activeColor;
    String chartTitle;

    switch (_activeTab) {
      case 'total':
        activeColor = const Color(0xFFFF8C00);
        chartTitle = 'Monthly Total Bills';
        break;
      case 'paid':
        activeColor = const Color(0xFF059669);
        chartTitle = 'Monthly Paid Bills';
        break;
      case 'pending':
        activeColor = const Color(0xFFD97706);
        chartTitle = 'Monthly Pending Bills';
        break;
      case 'overdue':
        activeColor = const Color(0xFFDC2626);
        chartTitle = 'Monthly Overdue Bills';
        break;
      default:
        activeColor = const Color(0xFFFF8C00);
        chartTitle = 'Monthly Bills';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chartTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100,
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
                      reservedSize: 40,
                      interval: 100,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
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
                maxY: 1000,
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
                          toY: 1000,
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
                      return BarTooltipItem(
                        '$month\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: formatCurrencyFull(rod.toY),
                            style: TextStyle(
                              color: activeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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