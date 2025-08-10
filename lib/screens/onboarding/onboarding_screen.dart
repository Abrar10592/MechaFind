import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:math' as math;
import '../../utils.dart';
import '../../landing.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _radarController;
  late AnimationController _glowController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _radarAnimation;
  late Animation<double> _glowAnimation;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Find Nearby Mechanics',
      subtitle: 'Discover qualified mechanics in your area instantly with our smart location-based search',
      animation: OnboardingAnimationType.map,
      primaryColor: Color(0xFF00ACC1), // Electric teal
      secondaryColor: Color(0xFF0277BD),
    ),
    OnboardingPageData(
      title: 'Instant Help at Your Fingertips',
      subtitle: 'Get immediate assistance from verified mechanics with just a tap',
      animation: OnboardingAnimationType.mechanic,
      primaryColor: Color(0xFFFF6F00), // Vibrant orange
      secondaryColor: Color(0xFFE65100),
    ),
    OnboardingPageData(
      title: 'Reliable & Fast Service',
      subtitle: 'Experience lightning-fast response times and professional service quality',
      animation: OnboardingAnimationType.service,
      primaryColor: Color(0xFF2E7D32), // Professional green
      secondaryColor: Color(0xFF1B5E20),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _radarController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _radarAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _radarController.dispose();
    _glowController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const LandingPage(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutQuart,
                )),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
              const Color(0xFF1A237E),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background elements
              _buildAnimatedBackground(),
              
              // Main content
              Column(
                children: [
                  // Skip button
                  _buildTopBar(),
                  
                  // Page content
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
                        return AnimationLimiter(
                          child: _buildPageContent(_pages[index], index),
                        );
                      },
                    ),
                  ),
                  
                  // Bottom navigation
                  _buildBottomNavigation(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Floating particles
        ...List.generate(15, (index) {
          return AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              final offset = Offset(
                math.sin(_rotationAnimation.value + index * 0.5) * 50,
                math.cos(_rotationAnimation.value + index * 0.3) * 30,
              );
              return Positioned(
                left: (index * 50.0) % MediaQuery.of(context).size.width + offset.dx,
                top: (index * 80.0) % MediaQuery.of(context).size.height + offset.dy,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
        
        // Subtle grid pattern
        Positioned.fill(
          child: CustomPaint(
            painter: GridPatternPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo/Brand
          AnimationConfiguration.staggeredList(
            position: 0,
            duration: const Duration(milliseconds: 800),
            child: SlideAnimation(
              horizontalOffset: -50,
              child: FadeInAnimation(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MechFind',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.primaryFont,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Skip button
          if (_currentPage < _pages.length - 1)
            AnimationConfiguration.staggeredList(
              position: 1,
              duration: const Duration(milliseconds: 800),
              child: SlideAnimation(
                horizontalOffset: 50,
                child: FadeInAnimation(
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'skip'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingPageData page, int index) {
    return AnimationLimiter(
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 1000),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: _buildAnimationWidget(page.animation, page.primaryColor),
                ),
              ),
            ),
          ),
          
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title with animated text
                  AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 800),
                    child: SlideAnimation(
                      verticalOffset: 30,
                      child: FadeInAnimation(
                        child: Container(
                          child: AnimatedTextKit(
                            key: ValueKey(index),
                            animatedTexts: [
                              TypewriterAnimatedText(
                                page.title,
                                textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.primaryFont,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: page.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                speed: const Duration(milliseconds: 80),
                              ),
                            ],
                            totalRepeatCount: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Subtitle
                  AnimationConfiguration.staggeredList(
                    position: 2,
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 20,
                      child: FadeInAnimation(
                        child: Text(
                          page.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationWidget(OnboardingAnimationType type, Color primaryColor) {
    switch (type) {
      case OnboardingAnimationType.map:
        return _buildMapAnimation(primaryColor);
      case OnboardingAnimationType.mechanic:
        return _buildMechanicAnimation(primaryColor);
      case OnboardingAnimationType.service:
        return _buildServiceAnimation(primaryColor);
    }
  }

  Widget _buildMapAnimation(Color primaryColor) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radar sweep effect
            AnimatedBuilder(
              animation: _radarAnimation,
              builder: (context, child) {
                return Container(
                  width: 280 * _radarAnimation.value,
                  height: 280 * _radarAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3 * (1 - _radarAnimation.value)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            
            // Location pins
            ...List.generate(5, (index) {
              final angle = (index * 2 * math.pi / 5);
              final radius = 80.0;
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Positioned(
                    left: 140 + math.cos(angle) * radius - 12,
                    top: 140 + math.sin(angle) * radius - 24,
                    child: Transform.scale(
                      scale: index == 2 ? _pulseAnimation.value * 0.8 : 1.0,
                      child: Container(
                        width: 24,
                        height: 32,
                        child: Icon(
                          Icons.location_on,
                          color: index == 2 ? primaryColor : primaryColor.withOpacity(0.6),
                          size: 24,
                          shadows: [
                            Shadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            
            // Central map element
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.3),
                  ],
                ),
                border: Border.all(
                  color: primaryColor.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.map,
                color: primaryColor,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicAnimation(Color primaryColor) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floating tools
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Stack(
                children: [
                  ...List.generate(4, (index) {
                    final angle = _rotationAnimation.value + (index * math.pi / 2);
                    final radius = 100.0;
                    final icons = [Icons.build, Icons.settings, Icons.handyman, Icons.construction];
                    
                    return Positioned(
                      left: 140 + math.cos(angle) * radius - 20,
                      top: 140 + math.sin(angle) * radius - 20,
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withOpacity(0.1),
                              border: Border.all(
                                color: primaryColor.withOpacity(_glowAnimation.value * 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(_glowAnimation.value * 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              icons[index],
                              color: primaryColor,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          
          // Central mechanic figure
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withOpacity(0.2),
                  primaryColor.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: primaryColor.withOpacity(0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.engineering,
              color: primaryColor,
              size: 64,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceAnimation(Color primaryColor) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Speed lines
              ...List.generate(8, (index) {
                final angle = index * math.pi / 4;
                return Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 4,
                    height: 60 * _pulseAnimation.value,
                    margin: EdgeInsets.only(top: 120),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withOpacity(0.8),
                          primaryColor.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
              
              // Central service icon
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withOpacity(0.3),
                      primaryColor.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.5),
                    width: 3,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.speed,
                      color: primaryColor,
                      size: 72,
                    ),
                    Positioned(
                      bottom: 30,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '< 5 min',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          // Page indicators
          AnimationConfiguration.staggeredList(
            position: 0,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 20,
              child: FadeInAnimation(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? _pages[_currentPage].primaryColor
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: _currentPage == index
                            ? [
                                BoxShadow(
                                  color: _pages[_currentPage].primaryColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Get Started / Next button
          AnimationConfiguration.staggeredList(
            position: 1,
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            _pages[_currentPage].primaryColor,
                            _pages[_currentPage].secondaryColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentPage].primaryColor.withOpacity(
                              0.3 + (_glowAnimation.value * 0.2)
                            ),
                            blurRadius: 20,
                            spreadRadius: _glowAnimation.value * 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'get_started'.tr()
                                  : 'next'.tr(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.rocket_launch
                                  : Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String subtitle;
  final OnboardingAnimationType animation;
  final Color primaryColor;
  final Color secondaryColor;

  OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

enum OnboardingAnimationType {
  map,
  mechanic,
  service,
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 50.0;
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
