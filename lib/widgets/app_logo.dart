import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable app logo widget that displays the BillMinder logo
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;

  const AppLogo({super.key, this.size = 100, this.showBackground = false});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/billminder_logo.svg',
      width: size,
      height: size,
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
      child: SvgPicture.asset(
        'assets/images/billminder_logo.svg',
        width: size,
        height: size,
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
