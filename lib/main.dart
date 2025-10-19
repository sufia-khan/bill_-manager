import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/bill_manager_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'services/hive_service.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive
  await HiveService.init();

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
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BillManager',
        routes: {
          '/analytics': (context) => const AnalyticsScreen(),
          '/calendar': (context) => const CalendarScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8C00),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'sans-serif',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            surfaceTintColor: Colors.white,
            backgroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
          return const BillManagerScreen();
        }

        // Otherwise, show login screen
        return const LoginScreen();
      },
    );
  }
}
