import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/bill_manager_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/archived_bills_screen.dart';
// import 'screens/past_bills_screen.dart'; // Removed - paid bills now shown in Paid tab
// import 'screens/export_screen.dart'; // Hidden for MVP - will add later
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/notification_history_service.dart';
import 'services/pending_notification_service.dart';
import 'services/user_preferences_service.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/notification_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive
  await HiveService.init();

  // Run data migration for new fields
  await HiveService.migrateExistingBills();

  // Initialize user preferences
  await UserPreferencesService.init();

  // Initialize notification service
  await NotificationService().init();

  // Initialize notification history service
  await NotificationHistoryService.init();

  // Process any pending notifications that triggered while app was closed
  await PendingNotificationService.processPendingNotifications();

  // Set up notification tap handler
  NotificationService.onNotificationTapped = (String? billId) {
    if (billId != null) {
      // Navigate to bill details when notification is tapped
      MyApp.navigatorKey.currentState?.pushNamed(
        '/bill-details',
        arguments: billId,
      );
    }
  };

  // Note: Background task scheduling removed due to workmanager compatibility issues
  // Maintenance runs automatically on app startup via BillProvider.initialize()

  runApp(const MyApp());
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
              '/auth': (context) => const AuthScreen(),
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
  bool _hasShownOnboarding = false;
  bool _hasLoadedCurrency = false;
  bool _isShowingOnboarding = false;
  bool _showSplash = true;
  bool _splashFadeOut = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onSplashComplete() async {
    if (mounted) {
      setState(() => _splashFadeOut = true);
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _showSplash = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen with fade transition
    if (_showSplash) {
      return Stack(
        children: [
          // Main content behind splash (preloaded)
          if (_splashFadeOut)
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isAuthenticated) {
                  return const BillManagerScreen();
                }
                return const LoginScreen();
              },
            ),
          // Splash screen fading out
          if (!_splashFadeOut)
            SplashScreen(onComplete: _onSplashComplete)
          else
            FadeTransition(
              opacity: Tween<double>(
                begin: 1.0,
                end: 0.0,
              ).animate(_fadeAnimation),
              child: IgnorePointer(child: SplashScreen(onComplete: () {})),
            ),
        ],
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

        // If user is authenticated, show onboarding first (only once per user)
        if (authProvider.isAuthenticated) {
          final userId = authProvider.user?.uid;

          // Load currency from Firebase after authentication
          if (!_hasLoadedCurrency) {
            _hasLoadedCurrency = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Small delay to ensure Firebase is ready
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                await context.read<CurrencyProvider>().loadSavedCurrency();
              }
            });
          }

          // Check if THIS specific user has seen onboarding
          final hasSeenOnboarding = UserPreferencesService.hasSeenOnboarding(
            userId: userId,
          );

          // Show onboarding screen only once per user account
          // Use _isShowingOnboarding to prevent multiple navigations
          if (!hasSeenOnboarding &&
              !_hasShownOnboarding &&
              !_isShowingOnboarding) {
            _hasShownOnboarding = true;
            _isShowingOnboarding = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;

              // Navigate to onboarding and wait for it to complete
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(userId: userId),
                ),
              );

              // After onboarding completes, show notification dialog
              if (mounted && !_hasShownPermissionDialog) {
                _hasShownPermissionDialog = true;
                _showNotificationPermissionDialog(context);
              }
              _isShowingOnboarding = false;
            });
          } else if (hasSeenOnboarding && !_hasShownPermissionDialog) {
            // User has already seen onboarding, show notification dialog directly
            _hasShownPermissionDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showNotificationPermissionDialog(context);
              }
            });
          }

          return const BillManagerScreen();
        }

        // Reset flags when user logs out
        if (!authProvider.isAuthenticated) {
          _hasLoadedCurrency = false;
          _hasShownPermissionDialog = false;
          _hasShownOnboarding = false;
          _isShowingOnboarding = false;
        }

        // Otherwise, show login screen
        return const LoginScreen();
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
                color: const Color(0xFFF97316F5E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF97316E5CC)),
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
                color: const Color(0xFFF97316F5E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF97316E5CC)),
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
}
