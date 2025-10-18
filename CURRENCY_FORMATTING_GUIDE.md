# Currency Formatting Utility Guide

## Overview
Comprehensive currency formatting utilities for Flutter with support for:
- Short format (K, M, B, T, Q)
- Full format with commas
- Indian Number System (Lakh, Crore)
- Custom currency symbols
- Reusable AmountText widget with info icon

## Quick Start

### 1. Import the utilities
```dart
import 'package:bill_manager/utils/formatters.dart';
import 'package:bill_manager/widgets/amount_text.dart';
```

### 2. Use formatter functions

```dart
// Short format
formatCurrencyShort(1200);           // $1.20K
formatCurrencyShort(2500000);        // $2.50M
formatCurrencyShort(8390000000);     // $8.39B
formatCurrencyShort(1500000000000);  // $1.50T
formatCurrencyShort(300);            // $300.00

// Full format
formatCurrencyFull(1234567.89);      // $1,234,567.89

// Negative numbers
formatCurrencyShort(-2500);          // $-2.50K

// Custom currency
formatCurrencyShort(1250000, symbol: '₹');  // ₹1.25M
formatCurrencyShort(3600000000, symbol: '€'); // €3.60B

// Indian format
formatCurrencyIndian(150000);        // ₹1.50 L
formatCurrencyIndian(23000000);      // ₹2.30 Cr
```

### 3. Use AmountText widget

```dart
// Basic - short format
AmountText(
  amount: 12345678,
  short: true,
) // Shows: $12.35M

// With info icon (shows full amount on tap)
AmountText(
  amount: 12345678,
  short: true,
  showInfoIcon: true,
) // Shows: $12.35M with info icon

// Custom style
AmountText(
  amount: 5000000,
  short: true,
  showInfoIcon: true,
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFFFF8C00),
  ),
)

// Indian format
AmountText(
  amount: 2500000,
  short: true,
  useIndianFormat: true,
  currencySymbol: '₹',
) // Shows: ₹2.50 L
```

## Features

### ✅ Short Format Support
- **K** (Thousand): 1,000 - 999,999
- **M** (Million): 1,000,000 - 999,999,999
- **B** (Billion): 1,000,000,000 - 999,999,999,999
- **T** (Trillion): 1,000,000,000,000 - 999,999,999,999,999
- **Q** (Quadrillion): 1,000,000,000,000,000+

### ✅ Indian Number System
- **K** (Thousand): 1,000 - 99,999
- **L** (Lakh): 100,000 - 9,999,999
- **Cr** (Crore): 10,000,000+

### ✅ Info Icon Feature
- Tap icon to see full amount in bottom sheet
- Hover tooltip shows full amount
- Consistent with existing app design

### ✅ Null-Safe & Fast
- All functions are null-safe
- Handles edge cases (infinity, NaN)
- Optimized for performance

## Usage in Your App

### In Analytics Screen
```dart
Text(formatCurrencyShort(totalAmount))
// or
AmountText(
  amount: totalAmount,
  short: true,
  showInfoIcon: true,
)
```

### In Bill Cards
```dart
AmountText(
  amount: bill.amount,
  short: true,
  showInfoIcon: true,
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1F2937),
  ),
)
```

### In Summary Cards
```dart
AmountText(
  amount: thisMonthTotal,
  short: false,  // Show full amount
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  ),
)
```

## API Reference

### formatCurrencyShort()
```dart
String formatCurrencyShort(double value, {String symbol = '\$'})
```
Formats currency in short readable format (K, M, B, T, Q).

### formatCurrencyFull()
```dart
String formatCurrencyFull(double value, {String symbol = '\$'})
```
Formats currency with full precision and commas.

### formatCurrencyIndian()
```dart
String formatCurrencyIndian(double value, {String symbol = '₹'})
```
Formats currency in Indian Number System (Lakh, Crore).

### formatNumber()
```dart
String formatNumber(double value)
```
Formats number with commas (no currency symbol).

### AmountText Widget
```dart
AmountText({
  required double amount,
  bool short = false,
  bool showInfoIcon = false,
  String currencySymbol = '\$',
  TextStyle? style,
  bool useIndianFormat = false,
})
```

## Examples

See `lib/utils/amount_formatter_examples.dart` for complete examples including:
- Basic usage
- UI integration
- Card/list items
- Analytics displays

## Migration from Old Code

### Before:
```dart
Text(formatCurrencyShort(bill.amount))
```

### After (with info icon):
```dart
AmountText(
  amount: bill.amount,
  short: true,
  showInfoIcon: true,
)
```

## Notes

- The info icon bottom sheet matches your existing design
- All formatters handle negative numbers correctly
- Currency symbols can be customized per call
- Widget is fully responsive and accessible
