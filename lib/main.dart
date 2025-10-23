import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/bill_manager_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
// import 'screens/past_bills_screen.dart'; // Removed - paid bills now shown in Paid tab
// import 'screens/export_screen.dart'; // Hidden for MVP - will add later
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive
  await HiveService.init();

  // Run data migration for new fields
  await HiveService.migrateExistingBills();

  // Initialize notification service
  await NotificationService().init();

  // Note: Background task scheduling removed due to workmanager compatibility issues
  // Maintenance runs automatically on app startup via BillProvider.initialize()

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(
          create: (_) => CurrencyProvider()..loadSavedCurrency(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationSettingsProvider()..initialize(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'BillManager',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/analytics': (context) => const AnalyticsScreen(),
              // '/export': (context) => const ExportScreen(), // Hidden for MVP
              '/calendar': (context) => const CalendarScreen(),
              '/settings': (context) => const SettingsScreen(),
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

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasShownPermissionDialog = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading indicator while checking auth state
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
            ),
          );
        }

        // If user is authenticated, show home screen
        if (authProvider.isAuthenticated) {
          // Show notification permission dialog once after login
          if (!_hasShownPermissionDialog) {
            _hasShownPermissionDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNotificationPermissionDialog(context);
            });
          }
          return const BillManagerScreen();
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
              color: Color(0xFFFF8C00),
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
                  Icon(Icons.warning_amber, color: Color(0xFFFF8C00), size: 20),
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
              backgroundColor: const Color(0xFFFF8C00),
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

      if (context.mounted) {
        if (permissionGranted == false || !systemEnabled) {
          // Permission denied - show warning
          await _showPermissionDeniedWarning(context);
          // Disable notifications in app since system denied
          await notificationProvider.setNotificationsEnabled(false);
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

  Future<void> _showPermissionDeniedWarning(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Color(0xFFFF8C00), size: 28),
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
                        color: Color(0xFFFF8C00),
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
              backgroundColor: const Color(0xFFFF8C00),
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
