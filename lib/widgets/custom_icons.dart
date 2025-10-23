import 'package:flutter/material.dart';

class MoneyIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MoneyIcon({
    super.key,
    this.size = 24.0,
    this.color = const Color(0xFFFF8C00),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: MoneyIconPainter(color)),
    );
  }
}

class MoneyIconPainter extends CustomPainter {
  final Color color;

  MoneyIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw sun rays
    for (int i = 0; i < 8; i++) {
      final startRadius = size.width * 0.15;
      final endRadius = size.width * 0.35;

      final startX =
          centerX +
          (startRadius *
              (i % 2 == 0 ? 1 : 0.707) *
              (i < 4 ? 1 : (i < 6 ? -1 : (i == 6 ? -0.707 : 0.707))));
      final startY =
          centerY +
          (startRadius *
              (i % 2 == 0 ? 0.707 : 1) *
              (i < 4 ? (i < 2 ? 1 : -1) : (i == 4 ? -1 : 1)));

      final endX =
          centerX +
          (endRadius *
              (i % 2 == 0 ? 1 : 0.707) *
              (i < 4 ? 1 : (i < 6 ? -1 : (i == 6 ? -0.707 : 0.707))));
      final endY =
          centerY +
          (endRadius *
              (i % 2 == 0 ? 0.707 : 1) *
              (i < 4 ? (i < 2 ? 1 : -1) : (i == 4 ? -1 : 1)));

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    // Draw circle
    canvas.drawCircle(Offset(centerX, centerY), size.width * 0.25, paint);

    // Draw clock hands
    // Hour hand
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX, centerY - size.width * 0.12),
      paint,
    );
    // Minute hand
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX + size.width * 0.15, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 48.0});

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Subscriptions':
        return '📋';
      case 'Rent':
        return '🏠';
      case 'Utilities':
        return '💡';
      case 'Electricity':
        return '⚡';
      case 'Water':
        return '💧';
      case 'Gas':
        return '🔥';
      case 'Internet':
        return '🌐';
      case 'Phone':
        return '📱';
      case 'Streaming':
        return '📺';
      case 'Groceries':
        return '🛒';
      case 'Transport':
      case 'Transportation':
        return '🚌';
      case 'Fuel':
        return '⛽';
      case 'Insurance':
        return '🛡️';
      case 'Health':
      case 'Healthcare':
        return '💊';
      case 'Medical':
        return '🏥';
      case 'Education':
        return '📚';
      case 'Entertainment':
        return '🎬';
      case 'Credit Card':
        return '💳';
      case 'Loan':
        return '💰';
      case 'Taxes':
        return '📝';
      case 'Savings':
        return '🏦';
      case 'Donations':
        return '❤️';
      case 'Home Maintenance':
        return '🔧';
      case 'HOA':
        return '🏘️';
      case 'Gym':
        return '💪';
      case 'Food':
        return '🍔';
      default:
        return '📄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _getCategoryEmoji(category),
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}
