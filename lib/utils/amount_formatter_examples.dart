/// Example usage of currency formatting utilities
///
/// This file demonstrates how to use the formatters and AmountText widget

import 'package:flutter/material.dart';
import '../widgets/amount_text.dart';
import 'formatters.dart';

/// Example 1: Using formatter functions directly
void formatterExamples() {
  // Short format (K, M, B, T, Q)
  print(formatCurrencyShort(1200)); // $1.20K
  print(formatCurrencyShort(2500000)); // $2.50M
  print(formatCurrencyShort(8390000000)); // $8.39B
  print(formatCurrencyShort(1500000000000)); // $1.50T
  print(formatCurrencyShort(300)); // $300.00

  // Full format with commas
  print(formatCurrencyFull(1234567.89)); // $1,234,567.89

  // Negative numbers
  print(formatCurrencyShort(-2500)); // $-2.50K

  // Custom currency symbol
  print(formatCurrencyShort(1250000, symbol: '₹')); // ₹1.25M
  print(formatCurrencyShort(3600000000, symbol: '€')); // €3.60B

  // Indian number system
  print(formatCurrencyIndian(150000)); // ₹1.50 L (Lakh)
  print(formatCurrencyIndian(23000000)); // ₹2.30 Cr (Crore)

  // Number only (no symbol)
  print(formatNumber(1234567.89)); // 1,234,567.89
}

/// Example 2: Using AmountText widget in UI
class AmountTextExamples extends StatelessWidget {
  const AmountTextExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic usage - short format
        const AmountText(amount: 12345678, short: true), // Shows: $12.35M

        const SizedBox(height: 16),

        // Full format
        const AmountText(
          amount: 12345678,
          short: false,
        ), // Shows: $12,345,678.00

        const SizedBox(height: 16),

        // With info icon to show full amount
        const AmountText(
          amount: 12345678,
          short: true,
          showInfoIcon: true,
        ), // Shows: $12.35M with info icon

        const SizedBox(height: 16),

        // Custom style
        const AmountText(
          amount: 5000000,
          short: true,
          showInfoIcon: true,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),

        const SizedBox(height: 16),

        // Indian format
        const AmountText(
          amount: 2500000,
          short: true,
          useIndianFormat: true,
          currencySymbol: '₹',
        ), // Shows: ₹2.50 L

        const SizedBox(height: 16),

        // Euro currency
        const AmountText(
          amount: 8500000,
          short: true,
          currencySymbol: '€',
          showInfoIcon: true,
        ), // Shows: €8.50M with info icon
      ],
    );
  }
}

/// Example 3: Using in a card/list item
class BillAmountCard extends StatelessWidget {
  final String title;
  final double amount;

  const BillAmountCard({super.key, required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            AmountText(
              amount: amount,
              short: true,
              showInfoIcon: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF8C00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example 4: Using in analytics/charts
class AnalyticsAmountDisplay extends StatelessWidget {
  final double totalAmount;
  final int billCount;

  const AnalyticsAmountDisplay({
    super.key,
    required this.totalAmount,
    required this.billCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          AmountText(
            amount: totalAmount,
            short: true,
            showInfoIcon: true,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8C00),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$billCount bills',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
