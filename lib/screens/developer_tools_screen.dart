import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_service.dart';
import 'notification_test_screen.dart';

class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Developer Tools',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These tools are for testing and debugging purposes only.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notification Testing Section
            _buildSectionHeader('Notification Testing'),
            const SizedBox(height: 12),

            _buildToolItem(
              context,
              icon: Icons.science_outlined,
              title: 'Notification Test Screen',
              subtitle: 'Comprehensive notification testing tool',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationTestScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            _buildToolItem(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Test Immediate Notification',
              subtitle: 'Send a test notification right now',
              onTap: () => _testImmediateNotification(context),
            ),

            const SizedBox(height: 8),

            _buildToolItem(
              context,
              icon: Icons.alarm_add_outlined,
              title: 'Test Scheduled Notification',
              subtitle: 'Schedule notification for 10 seconds',
              onTap: () => _testScheduledNotification(context),
            ),

            const SizedBox(height: 8),

            _buildToolItem(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'Test Bill Notification (2 min)',
              subtitle: 'Creates a test bill with notification',
              onTap: () => _testBillNotification(context),
            ),

            const SizedBox(height: 24),

            // Status & Debug Section
            _buildSectionHeader('Status & Debug'),
            const SizedBox(height: 12),

            _buildToolItem(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Check Notification Status',
              subtitle: 'View permissions and settings',
              onTap: () => _checkNotificationStatus(context),
            ),

            const SizedBox(height: 8),

            _buildToolItem(
              context,
              icon: Icons.schedule_outlined,
              subtitle: 'See all pending notifications',
              onTap: () => _viewScheduledNotifications(context),
            ),

            const SizedBox(height: 8),

            _buildToolItem(
              context,
              icon: Icons.refresh_rounded,
              title: 'Reschedule All Notifications',
              subtitle: 'Cancel and re-schedule all alarms',
              onTap: () => _rescheduleAllNotifications(context),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildToolItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Future<void> _testImmediateNotification(BuildContext context) async {
    final notificationService = NotificationService();
    final notificationProvider = Provider.of<NotificationSettingsProvider>(
      context,
      listen: false,
    );

    if (!notificationProvider.notificationsEnabled) {
      _showSnackBar(
        context,
        'Please enable notifications first',
        isError: true,
      );
      return;
    }

    final hasPermission = await notificationService.areNotificationsEnabled();
    if (!hasPermission) {
      _showSnackBar(
        context,
        'Please enable notifications in system settings',
        isError: true,
      );
      return;
    }

    await notificationService.showImmediateNotification(
      'Immediate Test Notification',
      'This appeared instantly! Your notifications are working perfectly!',
    );

    _showSnackBar(context, 'Test notification sent successfully!');
  }

  Future<void> _testScheduledNotification(BuildContext context) async {
    final notificationService = NotificationService();
    final canScheduleExact = await notificationService.canScheduleExactAlarms();

    if (!canScheduleExact) {
      _showPermissionDialog(context, notificationService);
      return;
    }

    try {
      await notificationService.scheduleTestNotification();
      _showSnackBar(
        context,
        'Notification scheduled for 10 seconds! Close the app to test.',
      );
    } catch (e) {
      _showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _testBillNotification(BuildContext context) async {
    try {
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      final now = DateTime.now();
      final notificationTime = now.add(const Duration(minutes: 2));

      await billProvider.addBill(
        title: 'Test Bill (Auto-created)',
        vendor: 'Test Vendor',
        amount: 10.00,
        dueAt: now,
        category: 'Other',
        repeat: 'none',
        notes:
            'This is a test bill created automatically. You can delete it after testing.',
        reminderTiming: 'Same Day',
        notificationTime: '${notificationTime.hour}:${notificationTime.minute}',
      );

      _showSnackBar(
        context,
        'Test bill created! Notification at ${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      _showSnackBar(context, 'Error creating test bill: $e', isError: true);
    }
  }

  Future<void> _checkNotificationStatus(BuildContext context) async {
    final notificationService = NotificationService();
    final enabled = await notificationService.areNotificationsEnabled();
    final exactAlarms = await notificationService.canScheduleExactAlarms();
    final pending = await notificationService.getPendingNotifications();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Notifications Enabled', enabled),
            const SizedBox(height: 8),
            _buildStatusRow('Exact Alarms Enabled', exactAlarms),
            const SizedBox(height: 8),
            Text(
              'Pending Notifications: ${pending.length}',
              style: const TextStyle(fontSize: 14),
            ),
            if (!enabled || !exactAlarms) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Action Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!enabled)
                      const Text(
                        '• Enable notifications in Settings > Apps > BillManager > Notifications',
                        style: TextStyle(fontSize: 12),
                      ),
                    if (!exactAlarms)
                      const Text(
                        '• Enable exact alarms in Settings > Apps > BillManager > Alarms & reminders',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!enabled || !exactAlarms)
            TextButton(
              onPressed: () async {
                await notificationService.requestPermissions();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Request Permissions'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewScheduledNotifications(BuildContext context) async {
    final notificationService = NotificationService();
    final pending = await notificationService.getPendingNotifications();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduled Notifications'),
        content: pending.isEmpty
            ? const Text('No notifications scheduled')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final notification = pending[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.notifications,
                        color: Color(0xFFFF8C00),
                      ),
                      title: Text(notification.title ?? 'No title'),
                      subtitle: Text(notification.body ?? 'No body'),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _rescheduleAllNotifications(BuildContext context) async {
    try {
      final billProvider = Provider.of<BillProvider>(context, listen: false);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF97316)),
        ),
      );

      await billProvider.rescheduleAllNotifications();

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        _showSnackBar(context, 'All notifications rescheduled successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        _showSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _showPermissionDialog(
    BuildContext context,
    NotificationService notificationService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm_off, color: Colors.red),
            SizedBox(width: 12),
            Expanded(child: Text('Permission Required')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scheduled notifications require "Alarms & reminders" permission.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              'How to enable:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '1. Go to Settings > Apps > BillManager\n'
              '2. Tap "Alarms & reminders"\n'
              '3. Enable "Allow setting alarms and reminders"',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await notificationService.requestPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            child: const Text('Request Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          status ? 'Yes' : 'No',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: status ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
