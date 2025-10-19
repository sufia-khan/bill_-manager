import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedSubtitle extends StatefulWidget {
  const AnimatedSubtitle({super.key});

  @override
  State<AnimatedSubtitle> createState() => _AnimatedSubtitleState();
}

class _AnimatedSubtitleState extends State<AnimatedSubtitle>
    with TickerProviderStateMixin {
  static const List<String> subtitles = [
    "Handle bills in seconds",
    "Never miss a due date",
    "Stay ahead effortlessly",
    "Smart tracking, zero stress",
    "Payments always in control",
    "Plan better, live easier",
    "Reminders that calm you",
    "Goodbye late fees forever",
    "Know dues before they hit",
    "Track, manage, relax",
    "Organized bills, organized life",
    "All payments in one place",
    "Clear bills, clear mind",
    "Effortless planning, always",
    "Stay on top with ease",
    "From overdue to on-time",
    "Your pocket finance buddy",
    "Spend smarter every day",
    "Always pay on time",
    "Stress less, stay sharp",
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  int _currentIndex = 0;
  String _displayText = '';
  bool _isDeleting = false;
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _startTyping();
    _fadeController.forward();
    _slideController.forward();
  }

  void _startTyping() {
    _charIndex = 0;
    _isDeleting = false;
    _typeNextChar();
  }

  void _typeNextChar() {
    final currentText = subtitles[_currentIndex];
    final typingSpeed = _isDeleting
        ? const Duration(milliseconds: 50)
        : const Duration(milliseconds: 100);

    _timer = Timer(typingSpeed, () {
      if (!mounted) return;

      setState(() {
        if (!_isDeleting) {
          // Typing mode
          if (_charIndex < currentText.length) {
            _displayText = currentText.substring(0, _charIndex + 1);
            _charIndex++;
            _typeNextChar();
          } else {
            // Finished typing, wait then start deleting
            _timer = Timer(const Duration(milliseconds: 3000), () {
              if (!mounted) return;
              setState(() {
                _isDeleting = true;
                _typeNextChar();
              });
            });
          }
        } else {
          // Deleting mode
          if (_charIndex > 0) {
            _displayText = currentText.substring(0, _charIndex - 1);
            _charIndex--;
            _typeNextChar();
          } else {
            // Finished deleting, move to next subtitle
            _fadeController.reverse().then((_) {
              if (!mounted) return;
              setState(() {
                _currentIndex = (_currentIndex + 1) % subtitles.length;
                _displayText = '';
                _isDeleting = false;
                _charIndex = 0;
              });
              _fadeController.forward();
              _startTyping();
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          child: Text(
            _displayText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ),
    );
  }
}
