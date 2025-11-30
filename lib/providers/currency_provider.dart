import 'package:flutter/foundation.dart';
import '../models/currency.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../utils/formatters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CurrencyProvider with ChangeNotifier {
  Currency _selectedCurrency = Currency.currencies[0]; // Default to USD
  bool _convertAmounts = false;
  double _conversionRate = 1.0;

  Currency get selectedCurrency => _selectedCurrency;
  bool get convertAmounts => _convertAmounts;
  double get conversionRate => _conversionRate;

  // Load saved currency on init
  Future<void> loadSavedCurrency() async {
    try {
      // First, try to load from Firebase if user is authenticated
      final userId = FirebaseService.currentUserId;
      if (userId != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('currency')
              .get();

          if (doc.exists) {
            final data = doc.data()!;
            final savedCode = data['currency_code'] as String?;
            final savedConvert = data['currency_convert'] as bool?;
            final savedRate = (data['currency_rate'] as num?)?.toDouble();

            if (savedCode != null) {
              final currency = Currency.currencies.firstWhere(
                (c) => c.code == savedCode,
                orElse: () => Currency.currencies[0],
              );
              _selectedCurrency = currency;
              _convertAmounts = savedConvert ?? false;
              _conversionRate = savedRate ?? 1.0;

              // Save to local storage for offline access
              await HiveService.saveUserData('currency_code', currency.code);
              await HiveService.saveUserData(
                'currency_convert',
                _convertAmounts,
              );
              await HiveService.saveUserData('currency_rate', _conversionRate);

              // Update global currency symbol
              setGlobalCurrencySymbol(currency.symbol);

              notifyListeners();
              return;
            }
          }
        } catch (e) {
          print('Error loading currency from Firebase: $e');
          // Fall back to local storage
        }
      }

      // Fall back to local storage if Firebase fails or user not authenticated
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
    try {
      _selectedCurrency = currency;
      _convertAmounts = convertAmounts;
      _conversionRate = conversionRate;

      // Update global currency symbol for formatters
      setGlobalCurrencySymbol(currency.symbol);

      // Save to local storage
      await HiveService.saveUserData('currency_code', currency.code);
      await HiveService.saveUserData('currency_convert', convertAmounts);
      await HiveService.saveUserData('currency_rate', conversionRate);

      // Save to Firebase if user is authenticated
      final userId = FirebaseService.currentUserId;
      if (userId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('currency')
              .set({
                'currency_code': currency.code,
                'currency_convert': convertAmounts,
                'currency_rate': conversionRate,
                'updated_at': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          print('Error saving currency to Firebase: $e');
          // Don't throw - local save succeeded
        }
      }

      notifyListeners();
    } catch (e) {
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
