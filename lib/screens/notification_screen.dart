import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Notification data
  final List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'title': 'Electricity Bill Due Soon',
      'message': 'Your electricity bill is due in 2 days.',
      'time': '2h ago',
      'type': 'upcoming',
    },
    {
      'id': 2,
      'title': 'Water Bill Paid',
      'message': 'You successfully paid your water bill.',
      'time': '5h ago',
      'type': 'paid',
    },
    {
      'id': 3,
      'title': 'Internet Bill Overdue',
      'message': 'Your internet bill payment is overdue.',
      'time': '1d ago',
      'type': 'overdue',
    },
  ];

  Widget _getIcon(String type) {
    switch (type) {
      case 'paid':
        return const Icon(Icons.check_circle, color: Color(0xFF059669), size: 22);
      case 'overdue':
        return const Icon(Icons.warning, color: Color(0xFFDC2626), size: 22);
      default:
        return const Icon(Icons.access_time, color: Color(0xFFFF8C00), size: 22);
    }
  }

  void _clearAllNotifications() {
    setState(() {
      notifications.clear();
    });
  }

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
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF8C00),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _clearAllNotifications,
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: Colors.grey.shade600,
              size: 22,
            ),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Column(
        children: [

          // Notification list
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 80,
                          color: Color(0xFFFF8C00),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You\'ll see bill reminders and updates here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C00).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon container
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: _getIcon(notif['type']),
                            ),
                            const SizedBox(width: 16),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif['message'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notif['time'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}