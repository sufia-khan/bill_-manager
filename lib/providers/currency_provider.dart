import 'package:flutter/foundation.dart';
import '../models/currency.dart';
import '../services/hive_service.dart';
import '../utils/formatters.dart';

class CurrencyProvider with ChangeNotifier {
  Currency _selectedCurrency = Currency.currencies[0]; // Default to USD
  bool _convertAmounts = false;
  double _conversionRate = 1.0;
  bool _isLoading = false;

  Currency get selectedCurrency => _selectedCurrency;
  bool get convertAmounts => _convertAmounts;
  double get conversionRate => _conversionRate;
  bool get isLoading => _isLoading;

  // Load saved currency on init
  Future<void> loadSavedCurrency() async {
    try {
      final savedCode = HiveService.getUserData('currency_code');
      final savedConvert = HiveService.getUserData('currency_convert');
      final savedRate = HiveService.getUserData('currency_rate');

      if (savedCode != null) {
        final currency = Currency.currencies.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => Currency.currencies[0],
        );
        _selectedCurrency = currency;
        _convertAmounts = savedConvert ?? false;
        _conversionRate = savedRate ?? 1.0;

        // Update global currency symbol
        setGlobalCurrencySymbol(currency.symbol);

        notifyListeners();
      } else {
        // Set default currency symbol
        setGlobalCurrencySymbol(_selectedCurrency.symbol);
      }
    } catch (e) {
      print('Error loading saved currency: $e');
      setGlobalCurrencySymbol(_selectedCurrency.symbol);
    }
  }

  Future<void> setCurrency(
    Currency currency,
    bool convertAmounts,
    double conversionRate,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Show loading spinner for 500ms for instant feel
      await Future.delayed(const Duration(milliseconds: 500));

      _selectedCurrency = currency;
      _convertAmounts = convertAmounts;
      _conversionRate = conversionRate;

      // Update global currency symbol for formatters
      setGlobalCurrencySymbol(currency.symbol);

      // Save to local storage
      await HiveService.saveUserData('currency_code', currency.code);
      await HiveService.saveUserData('currency_convert', convertAmounts);
      await HiveService.saveUserData('currency_rate', conversionRate);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
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
