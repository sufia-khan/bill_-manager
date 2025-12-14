import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/trial_service.dart';
import '../services/sync_service.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/user_preferences_service.dart';
import '../services/notification_service.dart';
import '../services/account_service.dart';
import '../widgets/currency_selector_sheet.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'terms_and_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import 'subscription_screen.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings & Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF97316),
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
            color: Color(0xFFF97316),
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
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
                                  color: Color(0xFFF97316),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF97316),
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
                            Color(0xFFF97316),
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
                        color: const Color(0xFFF97316),
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

            const SizedBox(height: 24),

            // Subscription/Trial Section
            _buildSubscriptionCard(),

            const SizedBox(height: 24),

            // 🧪 TESTING SECTION (Remove in production)
            _buildTestingSection(),

            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 12),

            // Notifications with Toggle
            Consumer<NotificationSettingsProvider>(
              builder: (context, notificationProvider, _) {
                return _buildSettingsOption(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  trailing: Switch(
                    value: notificationProvider.notificationsEnabled,
                    onChanged: (value) async {
                      await notificationProvider.setNotificationsEnabled(value);

                      // Reschedule or cancel all notifications based on the new setting
                      if (mounted) {
                        final billProvider = Provider.of<BillProvider>(
                          context,
                          listen: false,
                        );
                        await billProvider.rescheduleAllNotifications();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Notifications enabled - reminders scheduled'
                                  : 'Notifications disabled - all reminders cancelled',
                            ),
                            backgroundColor: const Color(0xFFF97316),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    activeColor: const Color(0xFFF97316),
                    activeTrackColor: const Color(
                      0xFFF97316,
                    ).withValues(alpha: 0.5),
                  ),
                  onTap: () async {
                    final notificationProvider =
                        Provider.of<NotificationSettingsProvider>(
                          context,
                          listen: false,
                        );
                    final newValue = !notificationProvider.notificationsEnabled;
                    await notificationProvider.setNotificationsEnabled(
                      newValue,
                    );

                    // Reschedule or cancel all notifications based on the new setting
                    if (mounted) {
                      final billProvider = Provider.of<BillProvider>(
                        context,
                        listen: false,
                      );
                      await billProvider.rescheduleAllNotifications();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newValue
                                ? 'Notifications enabled - reminders scheduled'
                                : 'Notifications disabled - all reminders cancelled',
                          ),
                          backgroundColor: const Color(0xFFF97316),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Default Reminder Time
            _buildSettingsOption(
              icon: Icons.access_time,
              title: 'Default Reminder Time',
              subtitle: 'Set preferred time for bill reminders',
              trailing: Text(
                _formatReminderTime(
                  UserPreferencesService.getDefaultReminderTime(),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _showReminderTimePicker(),
            ),
            const SizedBox(height: 12),

            // Currency (Pro feature to change)
            Consumer<CurrencyProvider>(
              builder: (context, currencyProvider, _) {
                final canChangeCurrency = TrialService.canChangeCurrency();
                return _buildSettingsOption(
                  icon: Icons.attach_money,
                  title: 'Currency',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!canChangeCurrency)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Text(
                        '${currencyProvider.selectedCurrency.code} (${currencyProvider.selectedCurrency.symbol})',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  onTap: !canChangeCurrency
                      ? () => _showProFeatureDialogSettings('Currency Settings')
                      : () {
                          // Capture the settings screen context
                          final settingsContext = context;

                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (sheetContext) => CurrencySelectorSheet(
                              currentCurrency:
                                  currencyProvider.selectedCurrency,
                              onCurrencySelected: (currency, convert, rate) async {
                                try {
                                  // Change currency immediately
                                  await currencyProvider.setCurrency(
                                    currency,
                                    convert,
                                    rate,
                                  );

                                  if (settingsContext.mounted) {
                                    // Navigate back to home screen (pop until we reach the first route)
                                    Navigator.of(
                                      settingsContext,
                                    ).popUntil((route) => route.isFirst);

                                    // Show success message
                                    ScaffoldMessenger.of(
                                      settingsContext,
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
                                                'Currency changed to ${currency.code}',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (settingsContext.mounted) {
                                    // Show error message
                                    ScaffoldMessenger.of(
                                      settingsContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.error,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Failed to change currency: $e',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                );
              },
            ),
            const SizedBox(height: 12),

            // Auto-Archive Paid Bills (Pro Feature)
            _buildSettingsOption(
              icon: Icons.archive_outlined,
              title: 'Auto-Archive',
              subtitle: 'Archive paid bills after 30 days',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!TrialService.canArchiveBills())
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Switch(
                    value:
                        TrialService.canArchiveBills() &&
                        UserPreferencesService.getAutoArchivePaidBills(),
                    onChanged: !TrialService.canArchiveBills()
                        ? null
                        : (value) async {
                            // Show confirmation dialog
                            final confirmed =
                                await _showAutoArchiveConfirmation(value);
                            if (confirmed == true) {
                              await UserPreferencesService.setAutoArchivePaidBills(
                                value,
                              );
                              setState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Auto-archive ${value ? 'enabled' : 'disabled'}',
                                    ),
                                    backgroundColor: const Color(0xFFF97316),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                    activeColor: const Color(0xFFF97316),
                    activeTrackColor: const Color(
                      0xFFF97316,
                    ).withValues(alpha: 0.5),
                  ),
                ],
              ),
              onTap: () {
                if (!TrialService.canArchiveBills()) {
                  _showProFeatureDialogSettings('Auto-Archive');
                }
              },
            ),

            const SizedBox(height: 24),

            // App Section
            _buildSectionHeader('App'),
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

            // Archived Bills (Pro Feature)
            _buildSettingsOption(
              icon: Icons.archive_outlined,
              title: 'Archived Bills',
              trailing: !TrialService.canArchiveBills()
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                      ],
                    )
                  : null,
              onTap: () {
                if (!TrialService.canArchiveBills()) {
                  _showProFeatureDialogSettings('Archive Bills');
                  return;
                }
                Navigator.pushNamed(context, '/archived-bills');
              },
            ),
            const SizedBox(height: 12),

            // Sync Now
            _buildSettingsOption(
              icon: Icons.sync,
              title: 'Sync Now',
              subtitle: 'Manually sync bills with cloud',
              onTap: () async {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFF97316)),
                            SizedBox(height: 16),
                            Text('Syncing bills...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  // Import sync service
                  final billProvider = Provider.of<BillProvider>(
                    context,
                    listen: false,
                  );
                  await billProvider.forceSync();

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Sync completed successfully!'),
                          ],
                        ),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Sync failed: $e')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
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

            const SizedBox(height: 24),

            // Legal Section
            _buildSectionHeader('Legal'),
            const SizedBox(height: 12),

            // Terms & Conditions
            _buildSettingsOption(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsAndConditionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Privacy Policy
            _buildSettingsOption(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader('Account'),
            const SizedBox(height: 12),

            // Logout
            _buildSettingsOption(
              icon: Icons.logout_outlined,
              title: 'Logout',
              titleColor: Colors.red,
              onTap: () async {
                // Check for unsynced bills
                final unsyncedCount = authProvider.getUnsyncedBillsCount();

                // Show dialog with 3 options
                final logoutChoice = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How would you like to logout?'),
                        if (unsyncedCount > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have $unsyncedCount unsynced bill${unsyncedCount != 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'cancel'),
                        child: const Text('Cancel'),
                      ),
                      if (unsyncedCount > 0)
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, 'logout_only'),
                          child: const Text(
                            'Logout Only',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, 'sync_logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          unsyncedCount > 0 ? 'Sync & Logout' : 'Logout',
                        ),
                      ),
                    ],
                  ),
                );

                if (logoutChoice == null || logoutChoice == 'cancel') {
                  // User cancelled, do nothing
                  return;
                }

                if (!mounted) return;

                if (logoutChoice == 'logout_only') {
                  // Show blur loading overlay
                  _showBlurLoadingOverlay(
                    title: 'Logging out...',
                    subtitle: 'Please wait',
                  );

                  // Logout without syncing - just clear and sign out
                  try {
                    // Cancel all notifications for this user
                    await NotificationService().cancelAllNotifications();
                    // Stop sync
                    SyncService.stopPeriodicSync();
                    // Clear local data
                    await HiveService.clearAllData();
                    // Clear session
                    await UserPreferencesService.clearSessionPreferences();
                    // Sign out
                    await FirebaseService.signOutGoogle();

                    if (mounted) {
                      // Close loading overlay
                      Navigator.pop(context);

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      // Close loading overlay
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logout failed: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else if (logoutChoice == 'sync_logout') {
                  // Check if online
                  final isOnline = await SyncService.isOnline();

                  if (!isOnline && unsyncedCount > 0) {
                    // Show network error dialog with auto-retry
                    if (mounted) {
                      final shouldRetry = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.wifi_off, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('No Internet'),
                            ],
                          ),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You need an internet connection to sync bills.',
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Please turn on WiFi or mobile data, then tap "Retry".',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );

                      // If user cancelled, don't logout
                      if (shouldRetry != true) return;

                      // User wants to retry - check network again
                      final isNowOnline = await SyncService.isOnline();
                      if (!isNowOnline) {
                        // Still offline - show error
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.wifi_off, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Still offline. Please check your connection.',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }

                      // Now online - proceed with sync
                    }
                  }

                  // Show blur loading overlay
                  if (mounted) {
                    _showBlurLoadingOverlay(
                      title: unsyncedCount > 0
                          ? 'Syncing & Logging out...'
                          : 'Logging out...',
                      subtitle: unsyncedCount > 0
                          ? 'Syncing $unsyncedCount bill${unsyncedCount == 1 ? '' : 's'} to cloud'
                          : 'Please wait',
                    );
                  }

                  try {
                    // Cancel all notifications for this user
                    await NotificationService().cancelAllNotifications();
                    await authProvider.signOut();

                    if (mounted) {
                      // Close loading overlay
                      Navigator.pop(context);

                      // Navigate to login
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      // Close loading overlay
                      Navigator.pop(context);

                      // Show error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logout failed: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // Delete Account
            _buildSettingsOption(
              icon: Icons.delete_forever_outlined,
              title: 'Delete Account',
              titleColor: Colors.red,
              onTap: () => _showDeleteAccountDialog(context, authProvider),
            ),
            const SizedBox(height: 80),

            // Footer
            Text(
              'BillMinder v1.0',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showAutoArchiveConfirmation(bool enabling) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          enabling ? Icons.archive_outlined : Icons.unarchive_outlined,
          color: const Color(0xFFF97316),
          size: 48,
        ),
        title: Text(
          enabling ? 'Enable Auto-Archive?' : 'Disable Auto-Archive?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enabling
                  ? 'Paid bills will be automatically archived after 30 days.'
                  : 'Paid bills will no longer be automatically archived.',
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    enabling ? Icons.info_outline : Icons.warning_amber,
                    color: const Color(0xFFF97316),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      enabling
                          ? 'You can always view archived bills in the Archived Bills section.'
                          : 'You will need to manually archive paid bills.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(enabling ? 'Enable' : 'Disable'),
          ),
        ],
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
              'BillMinder',
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
                  'BillMinder helps you stay on top of your finances by tracking all your bills in one place. Never miss a payment again!',
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
                          color: Color(0xFFF97316),
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
                color: Color(0xFFF97316),
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
                color: Color(0xFFF97316),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFF97316),
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
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFF97316)),
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
                color: (iconColor ?? const Color(0xFFF97316)).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? const Color(0xFFF97316),
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
    final isPro = (index == 1 || index == 2); // Analytics and Calendar are Pro
    final hasProAccess = TrialService.canAccessProFeatures();
    final showProBadge = isPro && !hasProAccess;

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
          // Analytics tab - Pro feature
          if (!TrialService.canAccessProFeatures()) {
            _showProFeatureDialogSettings('Advanced Analytics');
            setState(() {
              _selectedTabIndex = 3;
            });
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
          );
        } else if (index == 2) {
          // Calendar tab - Pro feature
          if (!TrialService.canAccessProFeatures()) {
            _showProFeatureDialogSettings('Calendar View');
            setState(() {
              _selectedTabIndex = 3;
            });
            return;
          }
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : Colors.grey.shade600,
                ),
                if (showProBadge)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFFF97316)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final status = TrialService.getMembershipStatus();
    final registrationDate = TrialService.getRegistrationDate();
    final daysRemaining = TrialService.getDaysRemaining();
    final trialEndDate = TrialService.getTrialEndDate();

    // Format dates
    final dateFormat = DateFormat('MMM d, yyyy');
    final memberSince = registrationDate != null
        ? dateFormat.format(registrationDate)
        : 'Unknown';
    final trialEnds = trialEndDate != null
        ? dateFormat.format(trialEndDate)
        : 'Unknown';

    // Only show upgrade button if trial is expiring soon (< 14 days) or expired
    final showUpgradeButton =
        status == MembershipStatus.free ||
        (status == MembershipStatus.trial && daysRemaining < 14);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: status == MembershipStatus.trial
              ? [
                  const Color(0xFFD4AF37),
                  const Color(0xFFF4C430),
                ] // Gold gradient
              : status == MembershipStatus.pro
              ? [
                  const Color(0xFFB8860B),
                  const Color(0xFFDAA520),
                ] // Dark gold for Pro
              : [
                  const Color(0xFF6B7280),
                  const Color(0xFF9CA3AF),
                ], // Gray for expired
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == MembershipStatus.pro
                          ? Icons.workspace_premium
                          : status == MembershipStatus.trial
                          ? Icons.star
                          : Icons.lock_outline,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status == MembershipStatus.pro
                          ? 'PRO'
                          : status == MembershipStatus.trial
                          ? 'FREE TRIAL'
                          : 'FREE',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Member since
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Since $memberSince',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trial status message
          if (status == MembershipStatus.trial) ...[
            Text(
              '$daysRemaining days remaining',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enjoy all Pro features until $trialEnds',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ] else if (status == MembershipStatus.pro) ...[
            const Text(
              'Pro Member',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Unlimited access to all features',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ] else ...[
            const Text(
              'Trial Expired',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Consumer<BillProvider>(
              builder: (context, billProvider, child) {
                final remainingBills = billProvider.getRemainingFreeTierBills();
                return Text(
                  'You can add $remainingBills more bill${remainingBills != 1 ? 's' : ''} (${TrialService.freeMaxBills} max)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              'Upgrade to Pro for unlimited bills',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],

          // Upgrade button (only show if trial expiring soon or expired)
          if (showUpgradeButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB8860B), // Dark gold
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  status == MembershipStatus.free
                      ? 'Upgrade to Pro'
                      : 'Upgrade Now - $daysRemaining days left',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (status == MembershipStatus.pro) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Manage Subscription',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '🧪 TESTING MODE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEV ONLY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Switch between trial states to test Pro features',
            style: TextStyle(fontSize: 13, color: Colors.purple.shade700),
          ),
          const SizedBox(height: 16),

          // Test mode buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestModeButton(
                'Trial Start',
                'trial_start',
                Icons.play_circle,
                Colors.green,
              ),
              _buildTestModeButton(
                'Trial Middle',
                'trial_middle',
                Icons.timelapse,
                Colors.blue,
              ),
              _buildTestModeButton(
                'Trial Ending',
                'trial_ending',
                Icons.warning,
                Colors.orange,
              ),
              _buildTestModeButton(
                'Trial Expired',
                'trial_expired',
                Icons.block,
                Colors.red,
              ),
              _buildTestModeButton(
                'Pro Member',
                'pro',
                Icons.workspace_premium,
                Colors.amber,
              ),
              _buildTestModeButton(
                'Real Mode',
                null,
                Icons.refresh,
                Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.purple.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current: ${TrialService.testMode ?? "Real Mode"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestModeButton(
    String label,
    String? mode,
    IconData icon,
    Color color,
  ) {
    final isActive = TrialService.testMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          TrialService.testMode = mode;
        });

        // Notify BillProvider to refresh so home screen shows correct value
        final billProvider = Provider.of<BillProvider>(context, listen: false);
        billProvider.refreshUI();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test mode: ${mode ?? "Real Mode"}'),
            backgroundColor: color,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isActive ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProFeatureDialogSettings(String featureName) {
    // Get feature details
    final featureDetails = _getFeatureDetails(featureName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                featureDetails['icon'] as IconData,
                color: const Color(0xFFD4AF37),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                featureName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feature-specific description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE5CC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_open,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            featureDetails['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      featureDetails['description'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trial status message
              Text(
                TrialService.getMembershipStatus() == MembershipStatus.free
                    ? 'Your free trial has ended. Upgrade to Pro to unlock all features.'
                    : 'Upgrade to Pro to unlock all premium features.',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Other Pro features
              const Text(
                'Other Pro Features:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              ...TrialService.getProFeaturesList()
                  .where((f) => f['title'] != featureDetails['title'])
                  .take(4)
                  .map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFD4AF37),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature['title'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFeatureDetails(String featureName) {
    switch (featureName) {
      case 'Currency Settings':
        return {
          'icon': Icons.attach_money,
          'title': 'Change Currency Anytime',
          'description':
              'Switch between different currencies and automatically convert all your bill amounts. Perfect for travelers or managing bills in multiple currencies.',
        };
      case 'Archive Bills':
        return {
          'icon': Icons.archive,
          'title': 'Archive Paid Bills',
          'description':
              'Keep your bill history organized by archiving paid bills. Access them anytime while keeping your active bills list clean and focused.',
        };
      case 'Recurring Bills':
        return {
          'icon': Icons.repeat,
          'title': 'Set Up Recurring Bills',
          'description':
              'Automatically create bills that repeat weekly, monthly, or yearly. Never manually add the same bill again - set it once and forget it.',
        };
      case 'Multiple Reminders':
        return {
          'icon': Icons.notifications_active,
          'title': 'Multiple Reminder Options',
          'description':
              'Get notified 1 day, 2 days, or 1 week before bills are due. Choose the perfect reminder timing for each bill.',
        };
      case 'Bill Notes':
        return {
          'icon': Icons.note,
          'title': 'Add Notes to Bills',
          'description':
              'Keep important information with each bill. Add account numbers, payment methods, or any details you need to remember.',
        };
      case 'Cloud Sync':
        return {
          'icon': Icons.cloud_sync,
          'title': 'Cloud Backup & Sync',
          'description':
              'Your bills are automatically backed up to the cloud and synced across all your devices. Never lose your data.',
        };
      case 'Advanced Analytics':
        return {
          'icon': Icons.analytics,
          'title': 'Advanced Analytics',
          'description':
              'Get detailed insights into your spending patterns with charts, trends, and category breakdowns. Make smarter financial decisions.',
        };
      case 'Export Data':
        return {
          'icon': Icons.file_download,
          'title': 'Export to CSV/PDF',
          'description':
              'Export your bills and reports to CSV or PDF format. Perfect for record-keeping, taxes, or sharing with accountants.',
        };
      case 'Unlimited Bills':
        return {
          'icon': Icons.all_inclusive,
          'title': 'Track Unlimited Bills',
          'description':
              'Add as many bills as you need without any limits. Free plan is limited to 5 bills, Pro gives you unlimited tracking.',
        };
      case 'All Categories':
        return {
          'icon': Icons.category,
          'title': 'Access All Categories',
          'description':
              'Choose from 30+ bill categories to organize your expenses. Free plan only has 10 basic categories.',
        };
      default:
        return {
          'icon': Icons.workspace_premium,
          'title': 'Pro Feature',
          'description':
              'This is a premium feature available only to Pro subscribers. Upgrade to unlock all Pro features.',
        };
    }
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
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
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFF97316)),
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

  String _formatReminderTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final displayMinute = minute.toString().padLeft(2, '0');
        return '$displayHour:$displayMinute $period';
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return time24;
  }

  /// Show a full-screen blur loading overlay with a message
  /// Displays loading indicator and text directly on blurred background
  void _showBlurLoadingOverlay({
    required String title,
    String? subtitle,
    Color? progressColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReminderTimePicker() async {
    final currentTime = UserPreferencesService.getDefaultReminderTime();
    final parts = currentTime.split(':');
    final initialHour = int.parse(parts[0]);
    final initialMinute = int.parse(parts[1]);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF97316),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF97316),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final time24 =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await UserPreferencesService.setDefaultReminderTime(time24);
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Default reminder time set to ${_formatReminderTime(time24)}',
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show delete account confirmation dialog
  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Account?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Your account and profile\n'
                    '• All bills and recurring history\n'
                    '• All notifications and reminders\n'
                    '• All data from this device and cloud',
                    style: TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show blur loading overlay
    _showBlurLoadingOverlay(
      title: 'Deleting account...',
      subtitle: 'Please wait while we remove all your data',
      progressColor: Colors.red,
    );

    // Perform account deletion
    final result = await AccountService.deleteAccount();

    if (!mounted) return;

    // Close loading overlay
    Navigator.pop(context);

    if (result.success) {
      // Reset BillProvider state
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      billProvider.reset();

      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Account deleted successfully'),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // Check if user is no longer logged in - navigate to login immediately
      final isNoUserError =
          result.error?.toLowerCase().contains('no user logged in') ?? false;

      if (isNoUserError) {
        // User was signed out - navigate to login screen
        if (mounted) {
          // Reset BillProvider state
          final billProvider = Provider.of<BillProvider>(
            context,
            listen: false,
          );
          billProvider.reset();

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );

          // Show info message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Session expired. Please log in again.'),
                ],
              ),
              backgroundColor: Color(0xFF3B82F6),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show error dialog with retry option
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                result.wasOffline ? Icons.wifi_off : Icons.error_outline,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Deletion Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Text(
            result.error ?? 'An unknown error occurred.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

      if (shouldRetry == true && mounted) {
        // Retry deletion
        _showDeleteAccountDialog(context, authProvider);
      }
    }
  }
}
