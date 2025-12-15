import 'package:flutter/material.dart';

/// Reusable app logo widget that displays the BillMinder logo
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;

  const AppLogo({super.key, this.size = 100, this.showBackground = false});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/my_app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Circular logo with optional shadow for splash/login screens
class AppLogoCircular extends StatelessWidget {
  final double size;
  final bool withShadow;

  const AppLogoCircular({super.key, this.size = 120, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    final logo = ClipOval(
      child: Image.asset(
        'assets/images/my_app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!withShadow) return logo;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: logo,
    );
  }
}
