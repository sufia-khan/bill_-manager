import 'package:intl/intl.dart';

/// Format currency with full precision and commas
/// Example: 1234567.89 → $1,234,567.89
String formatCurrencyFull(double value, {String symbol = '\$'}) {
  if (!value.isFinite) return value.toString();
  final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
  return formatter.format(value);
}

/// Format currency in short readable format
/// Examples:
/// 1,200 → $1.2K
/// 2,500,000 → $2.5M
/// 8,390,000,000 → $8.39B
/// 1,500,000,000,000 → $1.5T
String formatCurrencyShort(double value, {String symbol = '\$'}) {
  if (!value.isFinite) return formatCurrencyFull(value, symbol: symbol);

  final abs = value.abs();

  String result;

  if (abs >= 1e15) {
    // Quadrillion
    result = '${symbol}${(value / 1e15).toStringAsFixed(2)}Q';
  } else if (abs >= 1e12) {
    // Trillion
    result = '${symbol}${(value / 1e12).toStringAsFixed(2)}T';
  } else if (abs >= 1e9) {
    // Billion
    result = '${symbol}${(value / 1e9).toStringAsFixed(2)}B';
  } else if (abs >= 1e6) {
    // Million
    result = '${symbol}${(value / 1e6).toStringAsFixed(2)}M';
  } else if (abs >= 1e3) {
    // Thousand
    result = '${symbol}${(value / 1e3).toStringAsFixed(2)}K';
  } else {
    // Less than 1000
    result = '${symbol}${value.toStringAsFixed(2)}';
  }

  return result;
}

/// Format currency in Indian Number System
/// Examples:
/// 100,000 → ₹1.0 Lakh
/// 10,000,000 → ₹1.0 Crore
String formatCurrencyIndian(double value, {String symbol = '₹'}) {
  if (!value.isFinite) return value.toString();

  final abs = value.abs();

  String result;

  if (abs >= 1e7) {
    // Crore
    result = '${symbol}${(value / 1e7).toStringAsFixed(2)} Cr';
  } else if (abs >= 1e5) {
    // Lakh
    result = '${symbol}${(value / 1e5).toStringAsFixed(2)} L';
  } else if (abs >= 1e3) {
    // Thousand
    result = '${symbol}${(value / 1e3).toStringAsFixed(2)}K';
  } else {
    result = '${symbol}${value.toStringAsFixed(2)}';
  }

  return result;
}

/// Format number with commas (no currency symbol)
/// Example: 1234567.89 → 1,234,567.89
String formatNumber(double value) {
  if (!value.isFinite) return value.toString();
  return NumberFormat('#,##0.00').format(value);
}

/// Legacy function for backward compatibility
String formatCurrency(double value) {
  return formatCurrencyFull(value);
}

/// Get relative date text
String getRelativeDateText(String dateString) {
  final now = DateTime.now();
  final dueDate = DateTime.parse('${dateString}T00:00:00');

  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

  final difference = dueDay.difference(today).inDays;

  if (difference == 0) {
    return 'Today';
  } else if (difference == 1) {
    return 'Tomorrow';
  } else if (difference < 0) {
    return 'Overdue by ${difference.abs()} day${difference.abs() > 1 ? 's' : ''}';
  } else if (difference <= 7) {
    return 'in $difference day${difference > 1 ? 's' : ''}';
  } else {
    return DateFormat('MMM d').format(dueDate);
  }
}

/// Get formatted date
String getFormattedDate(String dateString) {
  final date = DateTime.parse('${dateString}T00:00:00');
  return DateFormat('MMM d, yyyy').format(date);
}
