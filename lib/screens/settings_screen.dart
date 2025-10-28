import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/currency_selector_sheet.dart';
import '../widgets/sync_stats_widget.dart';
import 'analytics_screen.dart';
import 'notification_test_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTabIndex = 3;
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditingProfile = true;
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Update profile
      await authProvider.user?.updateDisplayName(_nameController.text.trim());

      // Refresh user data in provider - this triggers UI update
      await authProvider.refreshUser();

      if (mounted) {
        setState(() {
          _isEditingProfile = false;
          _isSavingProfile = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Update controller when user changes
    if (!_isEditingProfile && user != null) {
      _nameController.text = user.displayName ?? '';
    }

    // Get user initials for avatar
    String getInitials(String? name, String? email) {
      if (name != null && name.isNotEmpty) {
        final parts = name.trim().split(' ');
        if (parts.length >= 2) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
      }
      if (email != null && email.isNotEmpty) {
        return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
      }
      return 'U';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings & Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF8C00),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFFF8C00),
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Section with Inline Edit
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8C00),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        getInitials(user?.displayName, user?.email),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditingProfile)
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF9CA3AF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF8C00),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF8C00),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          )
                        else
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'No email',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isSavingProfile)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF8C00),
                          ),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _isEditingProfile
                          ? _saveProfile
                          : _startEditing,
                      icon: Icon(
                        _isEditingProfile ? Icons.check : Icons.edit_outlined,
                        color: const Color(0xFFFF8C00),
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sync Status Section
            const SyncStatsWidget(),

            const SizedBox(height: 24),

            // Settings Options
            Column(
              children: [
                // Notifications with Toggle
                Consumer<NotificationSettingsProvider>(
                  builder: (context, notificationProvider, _) {
                    return _buildSettingsOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      trailing: Switch(
                        value: notificationProvider.notificationsEnabled,
                        onChanged: (value) async {
                          await notificationProvider.setNotificationsEnabled(
                            value,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Notifications ${value ? 'enabled' : 'disabled'}',
                                ),
                                backgroundColor: const Color(0xFFFF8C00),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        activeColor: const Color(0xFFFF8C00),
                        activeTrackColor: const Color(
                          0xFFFF8C00,
                        ).withValues(alpha: 0.5),
                      ),
                      onTap: () async {
                        final notificationProvider =
                            Provider.of<NotificationSettingsProvider>(
                              context,
                              listen: false,
                            );
                        await notificationProvider.setNotificationsEnabled(
                          !notificationProvider.notificationsEnabled,
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Notification Test Screen
                _buildSettingsOption(
                  icon: Icons.science_outlined,
                  title: 'Test Notifications',
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

                const SizedBox(height: 12),

                // Check Notification Status (Debug)
                _buildSettingsOption(
                  icon: Icons.bug_report_outlined,
                  title: 'Check Notification Status',
                  subtitle: 'Debug: Check permissions and settings',
                  onTap: () async {
                    final notificationService = NotificationService();

                    final enabled = await notificationService
                        .areNotificationsEnabled();
                    final exactAlarms = await notificationService
                        .canScheduleExactAlarms();
                    final pending = await notificationService
                        .getPendingNotifications();

                    if (mounted) {
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
                              _buildStatusRow(
                                'Exact Alarms Enabled',
                                exactAlarms,
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
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
                                  await notificationService
                                      .requestPermissions();
                                  Navigator.pop(context);
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
                  },
                ),

                const SizedBox(height: 12),

                // Show Pending Notifications (Debug)
                _buildSettingsOption(
                  icon: Icons.schedule_outlined,
                  title: 'View Scheduled Notifications',
                  subtitle: 'Debug: See all pending notifications',
                  onTap: () async {
                    final notificationService = NotificationService();
                    final pending = await notificationService
                        .getPendingNotifications();

                    if (mounted) {
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
                                        title: Text(
                                          notification.title ?? 'No title',
                                        ),
                                        subtitle: Text(
                                          notification.body ?? 'No body',
                                        ),
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
                  },
                ),

                const SizedBox(height: 12),

                // Test Scheduled Notification (10 seconds)
                _buildSettingsOption(
                  icon: Icons.alarm_add_outlined,
                  title: 'Test Scheduled Notification',
                  subtitle:
                      'Schedule notification for 10 seconds (works when app is closed)',
                  onTap: () async {
                    final notificationService = NotificationService();

                    // First check if exact alarms are enabled
                    final canScheduleExact = await notificationService
                        .canScheduleExactAlarms();

                    if (!canScheduleExact) {
                      if (mounted) {
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
                                  // Request permission
                                  await notificationService
                                      .requestPermissions();
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
                      return;
                    }

                    try {
                      await notificationService.scheduleTestNotification();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Notification scheduled for 10 seconds! Close the app to test.',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Test Bill Notification (2 minutes)
                _buildSettingsOption(
                  icon: Icons.receipt_long,
                  title: 'Test Bill Notification (2 min)',
                  subtitle:
                      'Creates a test bill with notification in 2 minutes',
                  onTap: () async {
                    try {
                      final billProvider = Provider.of<BillProvider>(
                        context,
                        listen: false,
                      );

                      // Calculate time 2 minutes from now
                      final now = DateTime.now();
                      final notificationTime = now.add(
                        const Duration(minutes: 2),
                      );

                      // Create a test bill due today with notification in 2 minutes
                      await billProvider.addBill(
                        title: 'Test Bill (Auto-created)',
                        vendor: 'Test Vendor',
                        amount: 10.00,
                        dueAt: now, // Due today
                        category: 'Other',
                        repeat: 'none',
                        notes:
                            'This is a test bill created automatically. You can delete it after testing.',
                        reminderTiming: 'Same Day',
                        notificationTime:
                            '${notificationTime.hour}:${notificationTime.minute}',
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Test bill created! Notification at ${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}. Close the app to test.',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'VIEW',
                              textColor: Colors.white,
                              onPressed: () {
                                Navigator.of(context).pop(); // Go back to home
                              },
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating test bill: $e'),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Test Notification
                _buildSettingsOption(
                  icon: Icons.notifications_active_outlined,
                  title: 'Test Notification (Immediate)',
                  onTap: () async {
                    final notificationService = NotificationService();

                    // Check if notifications are enabled
                    final notificationProvider =
                        Provider.of<NotificationSettingsProvider>(
                          context,
                          listen: false,
                        );

                    if (!notificationProvider.notificationsEnabled) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enable notifications first'),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      return;
                    }

                    // Check system permissions
                    final hasPermission = await notificationService
                        .areNotificationsEnabled();
                    if (!hasPermission) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enable notifications in system settings',
                            ),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                      return;
                    }

                    // Send test notification
                    await notificationService.showImmediateNotification(
                      'Immediate Test Notification',
                      'This appeared instantly! Your notifications are working perfectly! 🎉',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Test notification sent successfully!',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Currency
                Consumer<CurrencyProvider>(
                  builder: (context, currencyProvider, _) {
                    return _buildSettingsOption(
                      icon: Icons.attach_money,
                      title: 'Currency',
                      trailing: currencyProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF8C00),
                                ),
                              ),
                            )
                          : Text(
                              '${currencyProvider.selectedCurrency.code} (${currencyProvider.selectedCurrency.symbol})',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                      onTap: currencyProvider.isLoading
                          ? () {} // Disable tap while loading
                          : () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => CurrencySelectorSheet(
                                  currentCurrency:
                                      currencyProvider.selectedCurrency,
                                  onCurrencySelected: (currency, convert, rate) async {
                                    // Show loading overlay with blur
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      barrierColor: Colors.black54,
                                      builder: (context) => PopScope(
                                        canPop: false,
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 5,
                                            sigmaY: 5,
                                          ),
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(32),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Color(0xFFFF8C00)),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Changing currency to ${currency.code}...',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Please wait',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    // Change currency in background
                                    currencyProvider
                                        .setCurrency(currency, convert, rate)
                                        .then((_) {
                                          if (mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // Close loading
                                          }
                                        });

                                    // Navigate to home immediately
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );
                                    if (mounted) {
                                      Navigator.pop(context); // Close settings
                                      Navigator.pop(context); // Go to home
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Currency changed to ${currency.code} • All amounts updated!',
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(
                                            0xFF059669,
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Privacy & Security
                _buildSettingsOption(
                  icon: Icons.security_outlined,
                  title: 'Privacy & Security',
                  onTap: () {
                    _showPrivacySecurityScreen(context, authProvider);
                  },
                ),

                const SizedBox(height: 12),

                // Archived Bills
                _buildSettingsOption(
                  icon: Icons.archive_outlined,
                  title: 'Archived Bills',
                  onTap: () {
                    Navigator.pushNamed(context, '/archived-bills');
                  },
                ),

                const SizedBox(height: 12),

                // View Onboarding
                _buildSettingsOption(
                  icon: Icons.auto_stories_outlined,
                  title: 'View Onboarding',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // About App
                _buildSettingsOption(
                  icon: Icons.info_outlined,
                  title: 'About App',
                  onTap: () {
                    _showAboutAppDialog(context);
                  },
                ),

                const SizedBox(height: 12),

                // Logout
                _buildSettingsOption(
                  icon: Icons.logout_outlined,
                  title: 'Logout',
                  titleColor: Colors.red,
                  onTap: () async {
                    // Show confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && mounted) {
                      await authProvider.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 80),

            // Footer
            const Text(
              'Bill Manager v1.0 • Designed with ❤️ in Orange & White',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('📱', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Text(
              'Bill Manager',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        content: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your Smart Bill Management Solution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bill Manager helps you stay on top of your finances by tracking all your bills in one place. Never miss a payment again!',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                _buildFeatureItem(
                  '🔔',
                  'Smart Notifications',
                  'Get timely reminders before bills are due',
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  '📊',
                  'Spending Analytics',
                  'Visualize your spending patterns with charts',
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  '📅',
                  'Calendar View',
                  'See all your bills in an organized calendar',
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  '💰',
                  'Multi-Currency',
                  'Support for multiple currencies with live rates',
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  '☁️',
                  'Cloud Sync',
                  'Your data is safely synced across devices',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Pro Tip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF8C00),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enable notifications to never miss a bill payment and maintain a perfect payment history!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFFFF8C00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPrivacySecurityScreen(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Privacy & Security',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF8C00),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFFF8C00),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data Privacy Section
                const Text(
                  'Data Privacy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.cloud_outlined,
                  title: 'Cloud Storage',
                  description:
                      'Your bill data is securely stored in Firebase Cloud and synced across your devices.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.lock_outline,
                  title: 'Data Encryption',
                  description:
                      'All your data is encrypted in transit and at rest using industry-standard encryption.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.visibility_off_outlined,
                  title: 'Privacy First',
                  description:
                      'We never share your personal information or bill data with third parties.',
                ),

                const SizedBox(height: 32),

                // Security Section
                const Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Secure Authentication',
                  description:
                      'Your account is protected with Firebase Authentication, ensuring secure access to your data.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.shield_outlined,
                  title: 'Protected Data',
                  description:
                      'All sensitive information is protected with multiple layers of security protocols.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.backup_outlined,
                  title: 'Automatic Backups',
                  description:
                      'Your data is automatically backed up to prevent any loss of information.',
                ),

                const SizedBox(height: 32),

                // Danger Zone
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  description: 'Permanently delete your account and all data',
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () {
                    _showDeleteAccountConfirmation(context, authProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFFF8C00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: titleColor == Colors.red
                ? Colors.red.withValues(alpha: 0.3)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFFFF8C00)).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? const Color(0xFFFF8C00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: titleColor ?? const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 48,
        ),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action is permanent and cannot be undone!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You will lose:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'All bills and payment history',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'Analytics and spending data',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'Account settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // TODO: Implement account deletion logic
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Account deleted'),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

        // Handle navigation for different tabs
        if (index == 0) {
          // Home tab
          Navigator.pop(context);
        } else if (index == 1) {
          // Analytics tab
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
          );
        } else if (index == 2) {
          // Calendar tab
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CalendarScreen()),
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

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return material.InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFFF8C00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? const Color(0xFF1F2937),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
            ] else ...[
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF6B7280),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
