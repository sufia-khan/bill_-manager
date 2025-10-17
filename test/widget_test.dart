// This is a basic Flutter widget test for the Bill Manager app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_manager/main.dart';
import 'package:bill_manager/utils/formatters.dart';

void main() {
  testWidgets('Bill Manager app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app loads with the correct title.
    expect(find.text('BillManager'), findsOneWidget);
    expect(find.text('Keep track of due dates — friendly reminders'), findsOneWidget);

    // Verify that some bills are displayed.
    expect(find.text('Electricity'), findsWidgets);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Rent'), findsWidgets);

    // Verify that currency formatting works.
    expect(find.text('\$85.50'), findsOneWidget);
    expect(find.text('\$9.99'), findsOneWidget);
  });

  testWidgets('Currency formatting functions work correctly', (WidgetTester tester) async {
    // Test formatCurrencyFull
    expect(formatCurrencyFull(1234.56), '\$1234.56');
    expect(formatCurrencyFull(1000000.0), '\$1000000.00');

    // Test formatCurrencyShort
    expect(formatCurrencyShort(1234.56), '\$1.23K');
    expect(formatCurrencyShort(1000000.0), '\$1M');
    expect(formatCurrencyShort(1500000000.0), '\$1.5B');
  });

  testWidgets('Settings toggle functionality', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify settings button exists.
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);

    // Tap settings button to open settings.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pump();

    // Verify settings section appears.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Compact amounts'), findsOneWidget);

    // Verify the toggle is initially on (default state).
    expect(find.byType(Switch), findsOneWidget);
  });
}
