import 'package:intl/intl.dart';

String formatCurrencyFull(double value) {
  final n = value;
  if (!n.isFinite) return value.toString();
  return '\$${n.toStringAsFixed(2)}';
}

String formatCurrencyShort(double value) {
  final n = value;
  if (!n.isFinite) return formatCurrencyFull(n);
  try {
    final formatted = NumberFormat.compactCurrency(
      decimalDigits: 1,
      symbol: '\$',
    ).format(n);
    if (RegExp(r'\d').hasMatch(formatted)) {
      return formatted.replaceAll(' ', '');
    }
    return formatCurrencyFull(n);
  } catch (e) {
    final abs = n.abs();
    if (abs >= 1e12) return '\$${(n / 1e12).toStringAsFixed(1)}T';
    if (abs >= 1e9) return '\$${(n / 1e9).toStringAsFixed(1)}B';
    if (abs >= 1e6) return '\$${(n / 1e6).toStringAsFixed(1)}M';
    if (abs >= 1e3) return '\$${(n / 1e3).toStringAsFixed(1)}K';
    return formatCurrencyFull(n);
  }
}

String formatCurrency(double value) {
  return '\$${value.toStringAsFixed(2)}';
}

String formatNumber(double value) {
  return NumberFormat.decimalPattern().format(value);
}

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

String getFormattedDate(String dateString) {
  final date = DateTime.parse('${dateString}T00:00:00');
  return DateFormat('MMM d, yyyy').format(date);
}