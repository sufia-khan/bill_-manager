import 'package:flutter/material.dart';
import '../services/user_preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Never Miss a Bill Again',
      description:
          'Your smart bill management solution that keeps all your bills organized in one place',
      icon: Icons.account_balance_wallet,
      gradient: const [Color(0xFFFF8C00), Color(0xFFFF8C00)],
      features: [],
    ),
    OnboardingPage(
      title: 'Track All Your Bills Effortlessly',
      description: 'Manage everything from rent to subscriptions with ease',
      icon: Icons.calendar_today,
      gradient: const [Color(0xFFFF8C00), Color(0xFFFFA500)],
      features: [
        '30+ custom categories',
        'Recurring bills support',
        'Multi-currency tracking',
        'Upcoming, Overdue & Paid tabs',
        'Quick summary cards',
      ],
    ),
    OnboardingPage(
      title: 'Stay Ahead with Timely Reminders',
      description: 'Get notified before bills are due and never miss a payment',
      icon: Icons.notifications_active,
      gradient: const [Color(0xFFEC4899), Color(0xFFEF4444)],
      features: [
        'Customizable notifications',
        'Pre-due date alerts',
        'Notification history',
        'Test notification feature',
        'Never miss deadlines',
      ],
    ),
    OnboardingPage(
      title: 'Understand Your Spending',
      description: 'Visual analytics and insights into your financial habits',
      icon: Icons.trending_up,
      gradient: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      features: [
        'Monthly spending charts',
        'Top 5 categories breakdown',
        'Track paid & pending bills',
        'Spending trends over time',
        'Filter by bill status',
      ],
    ),
    OnboardingPage(
      title: 'Your Data, Safe & Synced',
      description: 'Cloud backup with secure authentication across all devices',
      icon: Icons.shield,
      gradient: const [Color(0xFF10B981), Color(0xFF14B8A6)],
      features: [
        'Firebase cloud backup',
        'Access from any device',
        'Secure authentication',
        'Works offline',
        'Auto-sync when online',
      ],
    ),
    OnboardingPage(
      title: 'Ready to Take Control?',
      description: 'Join thousands managing their bills smarter',
      icon: Icons.check_circle,
      gradient: const [Color(0xFFFF8C00), Color(0xFFFF8C00)],
      features: [],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    // Mark onboarding as seen
    await UserPreferencesService.setOnboardingSeen();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 32 : 8,
                          decoration: BoxDecoration(
                            gradient: _currentPage == index
                                ? LinearGradient(colors: _pages[index].gradient)
                                : null,
                            color: _currentPage == index
                                ? null
                                : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0 ? _previousPage : null,
                        icon: const Icon(Icons.chevron_left),
                        iconSize: 32,
                        color: _currentPage > 0
                            ? const Color(0xFF374151)
                            : const Color(0xFFD1D5DB),
                      ),
                      if (_currentPage == _pages.length - 1)
                        const SizedBox(width: 48)
                      else
                        ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pages[_currentPage].gradient[0],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Skip button positioned absolutely in top-right corner
            if (_currentPage < _pages.length - 1)
              Positioned(
                top: 16,
                right: 8,
                child: TextButton(
                  onPressed: _skipToEnd,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    final isLastPage = _currentPage == _pages.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24.0, 60.0, 24.0, 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.gradient[0].withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(page.icon, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (page.features.isNotEmpty)
            Column(
              children: page.features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(-20 * (1 - value), 0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: page.gradient[0].withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: page.gradient),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          if (isLastPage) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.features,
  });
}
