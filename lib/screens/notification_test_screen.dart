import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Test screen to verify notifications are working properly
/// This helps debug notification issues
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _status = 'Ready to test';
  bool _isLoading = false;

  Future<void> _testImmediateNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending immediate notification...';
    });

    try {
      await NotificationService().showImmediateNotification(
        '✅ Test Notification',
        'If you see this, notifications are working! Time: ${DateTime.now().toString().substring(11, 19)}',
      );

      setState(() {
        _status =
            '✅ Immediate notification sent! Check your notification tray.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testScheduledNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Scheduling notification for 10 seconds from now...';
    });

    try {
      await NotificationService().scheduleTestNotification();

      setState(() {
        _status =
            '✅ Notification scheduled for 10 seconds from now!\n\n'
            'Close the app and wait 10 seconds.\n'
            'You should see a notification even with the app closed.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking permissions...';
    });

    try {
      final notificationService = NotificationService();
      final notificationsEnabled = await notificationService
          .areNotificationsEnabled();
      final canScheduleExact = await notificationService
          .canScheduleExactAlarms();

      setState(() {
        _status =
            '📋 Permission Status:\n\n'
            '• Notifications: ${notificationsEnabled ? "✅ Enabled" : "❌ Disabled"}\n'
            '• Exact Alarms: ${canScheduleExact ? "✅ Enabled" : "❌ Disabled"}\n\n'
            '${!notificationsEnabled ? "⚠️ Enable notifications in Settings\n" : ""}'
            '${!canScheduleExact ? "⚠️ Enable Alarms & reminders in Settings" : ""}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _viewPendingNotifications() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading pending notifications...';
    });

    try {
      final pending = await NotificationService().getPendingNotifications();

      if (pending.isEmpty) {
        setState(() {
          _status = '📋 No pending notifications scheduled';
          _isLoading = false;
        });
      } else {
        final buffer = StringBuffer('📋 Pending Notifications:\n\n');
        for (var i = 0; i < pending.length; i++) {
          buffer.writeln('${i + 1}. ${pending[i].title}');
          if (pending[i].body != null) {
            buffer.writeln('   ${pending[i].body}');
          }
          buffer.writeln();
        }

        setState(() {
          _status = buffer.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notification Test',
          style: TextStyle(
            color: Color(0xFFFF8C00),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFFF8C00),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8C00),
                      ),
                    )
                  else
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Buttons
            const Text(
              'Quick Tests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.notifications_active,
              label: 'Test Immediate Notification',
              description: 'Shows a notification right now',
              onPressed: _testImmediateNotification,
            ),

            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.schedule,
              label: 'Test Scheduled Notification',
              description: 'Schedules a notification for 10 seconds from now',
              onPressed: _testScheduledNotification,
            ),

            const SizedBox(height: 24),

            const Text(
              'Diagnostics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.security,
              label: 'Check Permissions',
              description: 'Verify notification permissions are granted',
              onPressed: _checkPermissions,
            ),

            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.list,
              label: 'View Pending Notifications',
              description: 'See all scheduled notifications',
              onPressed: _viewPendingNotifications,
            ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Testing Tips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Test immediate notification first\n'
                    '2. Then test scheduled notification\n'
                    '3. Close the app completely\n'
                    '4. Wait 10 seconds\n'
                    '5. You should see the notification\n\n'
                    'If notifications don\'t work:\n'
                    '• Check permissions\n'
                    '• Disable battery optimization\n'
                    '• Enable "Alarms & reminders"',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      height: 1.5,
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

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        padding: const EdgeInsets.all(16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF8C00), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }
}
