import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late List<Map<String, dynamic>> _eventsData;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _eventsData = [
      {
        'id': 1,
        'title': 'Electricity Bill',
        'time': '09:00 am',
        'description': 'Due for September',
        'color': const Color(0xFFFFF3CD),
        'date': DateTime.now().subtract(const Duration(days: 5)),
      },
      {
        'id': 2,
        'title': 'Internet Bill',
        'time': '11:00 am',
        'description': 'Due for September',
        'color': const Color(0xFFFFCC99),
        'date': DateTime.now().add(const Duration(days: 3)),
      },
      {
        'id': 3,
        'title': 'Netflix Subscription',
        'time': '01:00 pm',
        'description': 'Monthly subscription',
        'color': const Color(0xFFD4EDDA),
        'date': DateTime.now(),
      },
      {
        'id': 4,
        'title': 'Rent Payment',
        'time': '03:00 pm',
        'description': 'Monthly rent',
        'color': const Color(0xFFE7E7FF),
        'date': DateTime.now(),
      },
    ];
  }

  List<Map<String, dynamic>> getEventsForDay(DateTime day) {
    return _eventsData.where((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.year == day.year &&
          eventDate.month == day.month &&
          eventDate.day == day.day;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _addNewEvent() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final titleController = TextEditingController();
        final timeController = TextEditingController();
        final descriptionController = TextEditingController();

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Bill',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Bill Title',
                    hintText: 'Enter bill title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFFFE5CC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFFF8C00)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add notes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFFFE5CC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFFF8C00)),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        setState(() {
                          _eventsData.add({
                            'id': _eventsData.length + 1,
                            'title': titleController.text,
                            'time': DateFormat('hh:mm a').format(_selectedDate),
                            'description': descriptionController.text.isNotEmpty
                                ? descriptionController.text
                                : 'Due for ${DateFormat('MMMM yyyy').format(_selectedDate)}',
                            'color': const Color(0xFFFFF3CD),
                            'date': DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                            ),
                          });
                        });
                      }
                      Navigator.of(context).pop();
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bill added successfully!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;

    // Adjust for Monday as first day (0 = Monday, 6 = Sunday)
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
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFFFF8C00),
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
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
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        final currentDay = DateTime(_selectedDate.year, _selectedDate.month, day);
                        final isToday = currentDay.year == DateTime.now().year &&
                            currentDay.month == DateTime.now().month &&
                            currentDay.day == DateTime.now().day;
                        final events = getEventsForDay(currentDay);

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
                                      color: isToday ? Colors.white : const Color(0xFFFF8C00),
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
                          _isToday(_selectedDate) ? 'Today\'s Bills' : 'Bills for ${DateFormat('MMM dd').format(_selectedDate)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '${getEventsForDay(_selectedDate).length} bill${getEventsForDay(_selectedDate).length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (getEventsForDay(_selectedDate).isNotEmpty) ...[
                      ...getEventsForDay(_selectedDate).map((event) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: event['color'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['title'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event['time'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    Text(
                                      event['description'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
                              'Tap + to add a new bill',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEvent,
        backgroundColor: const Color(0xFFFF8C00),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}