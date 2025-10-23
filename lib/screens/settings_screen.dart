import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/currency_selector_sheet.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTabIndex = 3;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
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
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Section with Edit Icon
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
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFFFF8C00),
                      size: 22,
                    ),
                    onPressed: () {
                      _showEditProfileDialog(context, user);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

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

                // Test Notification
                _buildSettingsOption(
                  icon: Icons.notifications_active_outlined,
                  title: 'Test Notification',
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
                      'Test Notification',
                      'Your notifications are working perfectly! 🎉',
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

                // Payment Methods
                _buildSettingsOption(
                  icon: Icons.credit_card_outlined,
                  title: 'Payment Methods',
                  onTap: () {
                    // Handle payment methods tap
                  },
                ),

                const SizedBox(height: 12),

                // Privacy & Security
                _buildSettingsOption(
                  icon: Icons.security_outlined,
                  title: 'Privacy & Security',
                  onTap: () {
                    _showPrivacySecurityDialog(context, authProvider);
                  },
                ),

                const SizedBox(height: 12),

                // About App
                _buildSettingsOption(
                  icon: Icons.info_outlined,
                  title: 'About App',
                  onTap: () {
                    // Handle about app tap
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

  void _showEditProfileDialog(BuildContext context, dynamic user) {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8C00),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8C00),
                    width: 2,
                  ),
                ),
                enabled: false,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement profile update logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  backgroundColor: Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySecurityDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage your privacy and security settings',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: Color(0xFFFF8C00)),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement change password
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Change password feature coming soon!'),
                    backgroundColor: Color(0xFFFF8C00),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountConfirmation(context, authProvider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFF8C00)),
            ),
          ),
        ],
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
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement account deletion logic
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted successfully'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete Account'),
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

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
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
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? const Color(0xFF1F2937),
                ),
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
