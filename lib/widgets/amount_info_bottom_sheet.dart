import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class AmountInfoBottomSheet {
  static void show(
    BuildContext context, {
    required double amount,
    required int billCount,
    required String title,
    String? formattedAmount,
  }) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final symbol = currencyProvider.selectedCurrency.symbol;
    final displayFormatted =
        formattedAmount ?? _formatCurrencyCompact(amount, symbol);
    final fullAmount = _formatCurrencyFull(amount, symbol);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Amount Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Color(0xFFFF8C00),
                  size: 32,
                ),
              ),

              const SizedBox(height: 20),

              // Formatted Amount (shown first)
              Text(
                displayFormatted,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8C00),
                ),
              ),

              const SizedBox(height: 12),

              // Full Amount (shown below)
              Text(
                fullAmount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static String _formatCurrencyCompact(double amount, String symbol) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return '$symbol${amount.toStringAsFixed(2)}';
    }
  }

  static String _formatCurrencyFull(double amount, String symbol) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
