import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../models/bill_hive.dart';
import '../utils/formatters.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  int _selectedTabIndex = 2;
  bool _compactAmounts = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Ensure bills are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().initialize();
    });
  }

  void _showAmountBottomSheet(double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
      ),
    );
  }

  List<BillHive> getEventsForDay(DateTime day, List<BillHive> bills) {
    return bills.where((bill) {
      return bill.dueAt.year == day.year &&
          bill.dueAt.month == day.month &&
          bill.dueAt.day == day.day;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
        setState(() {
          _selectedTabIndex = index;
        });

        if (index == 0) {
          Navigator.pop(context);
        } else if (index == 1) {
          Navigator.pushNamed(context, '/analytics');
        } else if (index == 3) {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        final bills = billProvider.bills;

        final daysInMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
        ).day;
        final firstDayOfMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          1,
        );
        final startingWeekday = firstDayOfMonth.weekday;
        final adjustedWeekday = startingWeekday == 7 ? 0 : startingWeekday;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF9F0),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Bill Calendar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF8C00),
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFFFF8C00),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Calendar Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Month Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month - 1,
                                    1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                              color: const Color(0xFFFF8C00),
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month + 1,
                                    1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                              color: const Color(0xFFFF8C00),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Weekday Headers
                        Row(
                          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((
                            day,
                          ) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFFF8C00),
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 1,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                          itemCount: adjustedWeekday + daysInMonth,
                          itemBuilder: (context, index) {
                            if (index < adjustedWeekday) {
                              return const SizedBox.shrink();
                            }

                            final day = index - adjustedWeekday + 1;
                            final currentDay = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              day,
                            );
                            final isToday = _isToday(currentDay);
                            final events = getEventsForDay(currentDay, bills);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = currentDay;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? const Color(0xFFFF8C00)
                                      : events.isNotEmpty
                                      ? const Color(0xFFFFE5CC)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      day.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isToday
                                            ? Colors.white
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                    if (events.isNotEmpty)
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? Colors.white
                                              : const Color(0xFFFF8C00),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Events Section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                              _isToday(_selectedDate)
                                  ? 'Today\'s Bills'
                                  : 'Bills for ${DateFormat('MMM dd').format(_selectedDate)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              '${getEventsForDay(_selectedDate, bills).length} bill${getEventsForDay(_selectedDate, bills).length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (getEventsForDay(
                          _selectedDate,
                          bills,
                        ).isNotEmpty) ...[
                          ...getEventsForDay(_selectedDate, bills).map((bill) {
                            final statusColor = bill.isPaid
                                ? const Color(0xFFD4EDDA)
                                : (bill.dueAt.isBefore(DateTime.now())
                                      ? const Color(0xFFF8D7DA)
                                      : const Color(0xFFFFF3CD));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          bill.vendor,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final formattedAmount =
                                                _compactAmounts
                                                ? formatCurrencyShort(
                                                    bill.amount,
                                                  )
                                                : formatCurrencyFull(
                                                    bill.amount,
                                                  );
                                            final fullAmount =
                                                formatCurrencyFull(bill.amount);
                                            final isFormatted =
                                                formattedAmount != fullAmount;

                                            return Row(
                                              children: [
                                                Text(
                                                  '$formattedAmount • ${bill.category}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                                if (isFormatted) ...[
                                                  const SizedBox(width: 4),
                                                  InkWell(
                                                    onTap: () =>
                                                        _showAmountBottomSheet(
                                                          bill.amount,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.info_outline,
                                                        size: 12,
                                                        color: Color(
                                                          0xFF6B7280,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (bill.isPaid)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF059669),
                                      size: 24,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 32,
                                  color: Color(0xFF6B7280),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No bills scheduled',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add bills to see them here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
