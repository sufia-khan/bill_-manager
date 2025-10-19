import 'package:flutter/foundation.dart';
import '../models/currency.dart';

class CurrencyProvider with ChangeNotifier {
  Currency _selectedCurrency = Currency.currencies[0]; // Default to USD
  bool _convertAmounts = false;
  double _conversionRate = 1.0;

  Currency get selectedCurrency => _selectedCurrency;
  bool get convertAmounts => _convertAmounts;
  double get conversionRate => _conversionRate;

  void setCurrency(
    Currency currency,
    bool convertAmounts,
    double conversionRate,
  ) {
    _selectedCurrency = currency;
    _convertAmounts = convertAmounts;
    _conversionRate = conversionRate;
    notifyListeners();
  }

  double convertAmount(double amount) {
    if (_convertAmounts) {
      return amount * _conversionRate;
    }
    return amount;
  }

  String formatCurrency(double amount) {
    final convertedAmount = convertAmount(amount);
    return '${_selectedCurrency.symbol}${convertedAmount.toStringAsFixed(2)}';
  }

  String formatCurrencyShort(double amount) {
    final convertedAmount = convertAmount(amount);
    if (convertedAmount >= 1000000) {
      return '${_selectedCurrency.symbol}${(convertedAmount / 1000000).toStringAsFixed(1)}M';
    } else if (convertedAmount >= 1000) {
      return '${_selectedCurrency.symbol}${(convertedAmount / 1000).toStringAsFixed(1)}K';
    }
    return '${_selectedCurrency.symbol}${convertedAmount.toStringAsFixed(2)}';
  }
}
