import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// A reusable widget to display currency amounts with optional info icon
///
/// Usage:
/// ```dart
/// AmountText(
///   amount: 12345678,
///   short: true,              // Shows 12.35M
///   showInfoIcon: true,       // Shows info icon to view full amount
///   style: TextStyle(...),    // Custom text style
/// )
/// ```
class AmountText extends StatelessWidget {
  final double amount;
  final bool short;
  final bool showInfoIcon;
  final String currencySymbol;
  final TextStyle? style;
  final bool useIndianFormat;

  const AmountText({
    super.key,
    required this.amount,
    this.short = false,
    this.showInfoIcon = false,
    this.currencySymbol = '\$',
    this.style,
    this.useIndianFormat = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = _getFormattedAmount();
    final fullAmount = formatCurrencyFull(amount, symbol: currencySymbol);

    if (!showInfoIcon) {
      return Text(displayText, style: style);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Tooltip(
            message: 'Amount: $fullAmount',
            child: Text(
              displayText,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Tap to view full amount',
          child: InkWell(
            onTap: () => _showAmountBottomSheet(context, fullAmount),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getFormattedAmount() {
    if (useIndianFormat) {
      return formatCurrencyIndian(amount, symbol: currencySymbol);
    } else if (short) {
      return formatCurrencyShort(amount, symbol: currencySymbol);
    } else {
      return formatCurrencyFull(amount, symbol: currencySymbol);
    }
  }

  void _showAmountBottomSheet(BuildContext context, String fullAmount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                fullAmount,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8C00),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exact amount: $fullAmount',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact version without info icon for inline use
class AmountTextCompact extends StatelessWidget {
  final double amount;
  final bool short;
  final String currencySymbol;
  final TextStyle? style;

  const AmountTextCompact({
    super.key,
    required this.amount,
    this.short = true,
    this.currencySymbol = '\$',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = short
        ? formatCurrencyShort(amount, symbol: currencySymbol)
        : formatCurrencyFull(amount, symbol: currencySymbol);

    return Text(displayText, style: style);
  }
}
