import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/currency_provider.dart';
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
            // Profile Section
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
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Settings Options
            Column(
              children: [
                // Notifications
                _buildSettingsOption(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  trailing: const Text(
                    'On',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  onTap: () {
                    // Handle notifications tap
                  },
                ),

                const SizedBox(height: 12),

                // Theme
                _buildSettingsOption(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  trailing: const Text(
                    'Light',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  onTap: () {
                    // Handle theme tap
                  },
                ),

                const SizedBox(height: 12),

                // Currency
                Consumer<CurrencyProvider>(
                  builder: (context, currencyProvider, _) {
                    return _buildSettingsOption(
                      icon: Icons.attach_money,
                      title: 'Currency',
                      trailing: Text(
                        '${currencyProvider.selectedCurrency.code} (${currencyProvider.selectedCurrency.symbol})',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => CurrencySelectorSheet(
                            currentCurrency: currencyProvider.selectedCurrency,
                            onCurrencySelected: (currency, convert, rate) {
                              currencyProvider.setCurrency(
                                currency,
                                convert,
                                rate,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Currency changed to ${currency.code}',
                                  ),
                                  backgroundColor: const Color(0xFFFF8C00),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
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
                    // Handle privacy & security tap
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
