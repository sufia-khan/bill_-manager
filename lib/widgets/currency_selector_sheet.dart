import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/currency.dart';

class CurrencySelectorSheet extends StatefulWidget {
  final Currency currentCurrency;
  final Function(Currency, bool, double) onCurrencySelected;

  const CurrencySelectorSheet({
    super.key,
    required this.currentCurrency,
    required this.onCurrencySelected,
  });

  @override
  State<CurrencySelectorSheet> createState() => _CurrencySelectorSheetState();
}

class _CurrencySelectorSheetState extends State<CurrencySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Currency> _filteredCurrencies = Currency.currencies;
  Currency? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.currentCurrency;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = Currency.currencies;
      } else {
        _filteredCurrencies = Currency.currencies.where((currency) {
          return currency.name.toLowerCase().contains(query.toLowerCase()) ||
              currency.code.toLowerCase().contains(query.toLowerCase()) ||
              currency.symbol.contains(query);
        }).toList();
      }
    });
  }

  // Helper to get appropriate font size based on symbol length
  double _getSymbolFontSize(String symbol) {
    final length = symbol.length;
    if (length == 1) {
      return 20.0; // Single character symbols like $, €, £, ¥
    } else if (length == 2) {
      return 16.0; // Two character symbols like ₹, ₽
    } else if (length == 3) {
      return 14.0; // Three character symbols like CHF, DKK
    } else {
      return 12.0; // Longer symbols
    }
  }

  // Helper to get colorful pastel colors for currency symbols
  Color _getCurrencyColor(String currencyCode) {
    // Beautiful pastel colors for different currencies
    final colorMap = {
      'USD': const Color(0xFF93C5FD), // Pastel Blue
      'EUR': const Color(0xFFA78BFA), // Pastel Purple
      'GBP': const Color(0xFFFDA4AF), // Pastel Pink
      'JPY': const Color(0xFFFBBF24), // Pastel Yellow
      'CNY': const Color(0xFFEF4444), // Pastel Red
      'INR': const Color(0xFFFB923C), // Pastel Orange
      'AUD': const Color(0xFF34D399), // Pastel Green
      'CAD': const Color(0xFFFF6B9D), // Pastel Rose
      'CHF': const Color(0xFF60A5FA), // Pastel Sky Blue
      'SEK': const Color(0xFFFBBF24), // Pastel Amber
      'NZD': const Color(0xFF4ADE80), // Pastel Emerald
      'SGD': const Color(0xFFF472B6), // Pastel Pink
      'HKD': const Color(0xFFFCA5A5), // Pastel Red
      'NOK': const Color(0xFF818CF8), // Pastel Indigo
      'KRW': const Color(0xFFC084FC), // Pastel Purple
      'TRY': const Color(0xFFFF8A80), // Pastel Coral
      'RUB': const Color(0xFF90CAF9), // Pastel Light Blue
      'BRL': const Color(0xFF81C784), // Pastel Green
      'ZAR': const Color(0xFFFFD54F), // Pastel Yellow
      'MXN': const Color(0xFFFF8A65), // Pastel Deep Orange
      'IDR': const Color(0xFFBA68C8), // Pastel Purple
      'MYR': const Color(0xFF4DD0E1), // Pastel Cyan
      'PHP': const Color(0xFFAED581), // Pastel Light Green
      'THB': const Color(0xFFFFB74D), // Pastel Orange
      'DKK': const Color(0xFFE57373), // Pastel Red
      'PLN': const Color(0xFF9575CD), // Pastel Deep Purple
      'CZK': const Color(0xFF64B5F6), // Pastel Blue
      'ILS': const Color(0xFFFFD740), // Pastel Yellow
      'CLP': const Color(0xFFFF6E40), // Pastel Deep Orange
      'AED': const Color(0xFF4FC3F7), // Pastel Light Blue
      'SAR': const Color(0xFF66BB6A), // Pastel Green
    };

    // Return mapped color or generate a color based on hash
    if (colorMap.containsKey(currencyCode)) {
      return colorMap[currencyCode]!;
    }

    // Generate a pastel color based on currency code hash
    final hash = currencyCode.hashCode;
    final pastelColors = [
      const Color(0xFF93C5FD), // Pastel Blue
      const Color(0xFFA78BFA), // Pastel Purple
      const Color(0xFFFDA4AF), // Pastel Pink
      const Color(0xFFFBBF24), // Pastel Yellow
      const Color(0xFF34D399), // Pastel Green
      const Color(0xFFFB923C), // Pastel Orange
      const Color(0xFF60A5FA), // Pastel Sky
      const Color(0xFFF472B6), // Pastel Rose
      const Color(0xFF4ADE80), // Pastel Emerald
      const Color(0xFFC084FC), // Pastel Violet
    ];

    return pastelColors[hash.abs() % pastelColors.length];
  }

  void _showConversionBottomSheet(Currency currency) {
    // Simple confirmation dialog - only symbol change, no conversion
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Change Currency?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change currency from ${widget.currentCurrency.code} (${widget.currentCurrency.symbol}) to ${currency.code} (${currency.symbol})?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFF97316),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only the currency symbol will change. Amounts stay the same.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close confirmation dialog
                Navigator.pop(
                  this.context,
                ); // Close the currency selector sheet
                widget.onCurrencySelected(currency, false, 1.0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Change Currency'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCurrencies,
              decoration: InputDecoration(
                hintText: 'Search currency...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF97316),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Currency list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected = currency.code == _selectedCurrency?.code;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = currency;
                    });
                    _showConversionBottomSheet(currency);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF97316).withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF97316)
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getCurrencyColor(
                              currency.code,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              currency.symbol,
                              style: TextStyle(
                                fontSize: _getSymbolFontSize(currency.symbol),
                                fontWeight: FontWeight.w600,
                                color: _getCurrencyColor(currency.code),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currency.code} • ${currency.symbol}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFF97316),
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
