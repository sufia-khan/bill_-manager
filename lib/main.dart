import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/bill_manager_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/archived_bills_screen.dart';
// import 'screens/past_bills_screen.dart'; // Removed - paid bills now shown in Paid tab
// import 'screens/export_screen.dart'; // Hidden for MVP - will add later
import 'package:google_fonts/google_fonts.dart';
import 'services/hive_service.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/pending_notification_service.dart';
import 'services/pending_recurring_service.dart';
import 'services/notification_history_service.dart';
import 'services/offline_first_notification_service.dart';
import 'services/user_preferences_service.dart';
import 'services/archive_management_service.dart';
import 'utils/bill_status_helper.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/notification_settings_provider.dart';
import 'providers/notification_badge_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Only initialize essential services before app starts
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await HiveService.init();
  await UserPreferencesService.init();

  // Set up notification tap handler
  NotificationService.onNotificationTapped = (String? billId) async {
    if (billId != null && billId.isNotEmpty && billId != 'test_notification') {
      MyApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => BillManagerScreen(
            initialStatus: 'overdue',
            highlightBillId: billId,
          ),
        ),
        (route) => false,
      );
    }
  };

  runApp(const MyApp());

  // Run non-critical tasks in background AFTER app starts
  _initializeBackgroundTasks();
}

// Background initialization - doesn't block app startup
Future<void> _initializeBackgroundTasks() async {
  try {
    // Initialize notification service
    await NotificationService().init();

    // Initialize offline-first notification service
    await OfflineFirstNotificationService.init();

    // Initialize notification history
    await NotificationHistoryService.init();

    // Run data migration
    await HiveService.migrateExistingBills();

    // CRITICAL: Catch up on missed notifications (e.g., during logout)
    final userId = FirebaseService.currentUserId;
    if (userId != null) {
      await BillStatusHelper.catchUpMissedNotifications(userId);
    }

    // Process pending notifications
    await PendingNotificationService.processPendingNotifications();

    // Process pending recurring bills
    await PendingRecurringService.processPendingRecurringBills();

    // Auto-cleanup old archived bills
    final deletedCount = await ArchiveManagementService.performAutoCleanup();
    if (deletedCount > 0) {
      print('🗑️ Auto-deleted $deletedCount old archived bills');
    }
  } catch (e) {
    print('⚠️ Background initialization error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Global navigator key for notification navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => CurrencyProvider()..loadSavedCurrency(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationSettingsProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => NotificationBadgeProvider()),
        ChangeNotifierProxyProvider<NotificationSettingsProvider, BillProvider>(
          create: (_) => BillProvider(),
          update: (context, notificationSettings, previous) {
            final billProvider = previous ?? BillProvider();
            billProvider.setNotificationSettings(notificationSettings);
            return billProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'BillMinder',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/login': (context) => const LoginScreen(),
              '/auth': (context) => const LoginScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              // '/export': (context) => const ExportScreen(), // Hidden for MVP
              '/calendar': (context) => const CalendarScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/archived-bills': (context) => const ArchivedBillsScreen(),
              // '/past-bills': (context) => const PastBillsScreen(), // Removed - paid bills now shown in Paid tab
            },
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with SingleTickerProviderStateMixin {
  bool _hasShownPermissionDialog = false;
  bool _hasLoadedCurrency = false;
  bool _showSplash = true;
  late AnimationController _controller;
  late Animation<double> _shadowOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shadowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
          ),
        );

    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animations
    _controller.forward();

    // Hide splash after animation (longer duration to read features)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show custom splash screen first
    if (_showSplash) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Logo with animated shadow
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF97316,
                            ).withValues(alpha: 0.25 * _shadowOpacity.value),
                            blurRadius: 25 * _shadowOpacity.value,
                            offset: Offset(0, 10 * _shadowOpacity.value),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/billminder_logo.png',
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Animated text
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _textSlide,
                      child: Opacity(opacity: _textOpacity.value, child: child),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        'BillMinder',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Never miss a bill again',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Feature points
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(
                          children: [
                            _buildFeaturePoint(
                              '📋 Track all your bills in one place',
                            ),
                            const SizedBox(height: 12),
                            _buildFeaturePoint(
                              '🔔 Get timely payment reminders',
                            ),
                            const SizedBox(height: 12),
                            _buildFeaturePoint('📊 View spending analytics'),
                            const SizedBox(height: 12),
                            _buildFeaturePoint('☁️ Sync across all devices'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Loading indicator
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(opacity: _loaderOpacity.value, child: child);
                  },
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFF97316),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading indicator while checking auth state
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            ),
          );
        }

        // If not authenticated, reset flags and show login
        if (!authProvider.isAuthenticated) {
          // CRITICAL: Reset BillProvider to clear cached data from previous user
          // This prevents bills from Account A showing up for Account B
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<BillProvider>().reset();
            }
          });
          // Reset all flags when user logs out
          _hasLoadedCurrency = false;
          _hasShownPermissionDialog = false;
          return const LoginScreen();
        }

        // User is authenticated
        final userId = authProvider.user?.uid;

        // Load currency from Firebase after authentication (in background)
        if (!_hasLoadedCurrency) {
          _hasLoadedCurrency = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Load currency in background without blocking UI
            if (mounted) {
              context.read<CurrencyProvider>().loadSavedCurrency();
            }
          });
        }

        // Check if THIS specific user has seen onboarding
        final hasSeenOnboarding = UserPreferencesService.hasSeenOnboarding(
          userId: userId,
        );

        // Show onboarding screen only once per user account
        if (!hasSeenOnboarding) {
          // Return OnboardingScreen directly instead of navigating
          // This prevents the flash of BillManagerScreen
          return OnboardingScreen(
            userId: userId,
            onComplete: () {
              if (mounted) {
                // Force rebuild to show BillManagerScreen
                setState(() {});
                // Show notification dialog after onboarding
                if (!_hasShownPermissionDialog) {
                  _hasShownPermissionDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showNotificationPermissionDialog(context);
                    }
                  });
                }
              }
            },
          );
        }

        // Show notification dialog for users who have already seen onboarding
        if (!_hasShownPermissionDialog) {
          _hasShownPermissionDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showNotificationPermissionDialog(context);
            }
          });
        }

        return const BillManagerScreen();
      },
    );
  }

  Future<void> _showNotificationPermissionDialog(BuildContext context) async {
    final notificationProvider = Provider.of<NotificationSettingsProvider>(
      context,
      listen: false,
    );

    // Check if already enabled
    if (notificationProvider.notificationsEnabled) {
      return;
    }

    // Show dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Color(0xFFF97316),
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable Notifications?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stay on top of your bills with timely reminders.',
              style: TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFF97316), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will not receive bill reminders if notifications are disabled.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
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
              'Not Now',
              style: TextStyle(color: Color(0xFF6B7280)),
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
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      // Enable notifications
      await notificationProvider.setNotificationsEnabled(true);

      // Request system permissions
      final permissionGranted = await NotificationService()
          .requestPermissions();

      // Check if system notifications are actually enabled
      final systemEnabled = await NotificationService()
          .areNotificationsEnabled();

      // Check if exact alarms are permitted (Android 12+)
      final canScheduleExact = await NotificationService()
          .canScheduleExactAlarms();

      if (context.mounted) {
        if (permissionGranted == false || !systemEnabled) {
          // Permission denied - show warning
          await _showPermissionDeniedWarning(context);
          // Disable notifications in app since system denied
          await notificationProvider.setNotificationsEnabled(false);
        } else if (!canScheduleExact) {
          // Exact alarms not permitted - show specific warning
          await _showExactAlarmWarning(context);
        } else {
          // Permission granted - reschedule notifications
          final billProvider = Provider.of<BillProvider>(
            context,
            listen: false,
          );
          await billProvider.rescheduleAllNotifications();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Notifications enabled successfully!'),
                  ],
                ),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _showExactAlarmWarning(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Color(0xFFF97316), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Exact Alarms Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To receive notifications at exact times, you need to enable "Alarms & reminders" permission.',
              style: TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFF97316),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'How to enable:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Go to Settings > Apps > BillManager\n'
                    '2. Tap "Alarms & reminders"\n'
                    '3. Enable "Allow setting alarms and reminders"',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDeniedWarning(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Color(0xFFF97316), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permission Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification permission was denied.',
              style: TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Color(0xFFF97316),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will not receive bill reminders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'To enable notifications, go to your phone Settings > Apps > BillManager > Notifications and turn them on.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
