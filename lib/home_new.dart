import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'package:mechfind/utils.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _cardController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _cardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _cardScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() {
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;
    
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
              AppColors.gradientEnd,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildFloatingElements(),
            _buildMainContent(isTablet: isTablet, isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Rotating gear elements
        ...List.generate(6, (index) {
          return AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              final angle = _rotationAnimation.value + (index * math.pi / 3);
              final radius = 120.0 + (index * 25);
              final size = MediaQuery.of(context).size;
              
              return Positioned(
                left: size.width / 2 + math.cos(angle) * radius - 20,
                top: size.height / 2 + math.sin(angle) * radius - 20,
                child: Opacity(
                  opacity: 0.08,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * (index.isEven ? 1 : -1),
                    child: Icon(
                      _getToolIcon(index),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  IconData _getToolIcon(int index) {
    final icons = [
      Icons.build_circle,
      Icons.settings,
      Icons.handyman,
      Icons.construction,
      Icons.engineering,
      Icons.car_repair,
    ];
    return icons[index % icons.length];
  }

  Widget _buildFloatingElements() {
    return Stack(
      children: List.generate(15, (index) {
        return AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            final size = MediaQuery.of(context).size;
            final angle = (_rotationAnimation.value * 0.5) + (index * 0.4);
            final radius = 40.0 + (index * 15);
            final x = size.width * 0.5 + math.cos(angle) * radius;
            final y = size.height * 0.3 + math.sin(angle) * radius * 0.5;
            
            return Positioned(
              left: x,
              top: y,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealPrimary.withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealPrimary.withOpacity(0.3),
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
    );
  }

  Widget _buildMainContent({required bool isTablet, required bool isDesktop}) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : isTablet ? 32.0 : 24.0,
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildHeroSection(isTablet: isTablet, isDesktop: isDesktop),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildQuickActions(isTablet: isTablet, isDesktop: isDesktop),
                    ),
                    _buildBottomActions(isTablet: isTablet, isDesktop: isDesktop),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection({required bool isTablet, required bool isDesktop}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated logo with pulse effect
        AnimationLimiter(
          child: AnimationConfiguration.staggeredList(
            position: 0,
            duration: const Duration(milliseconds: 800),
            child: ScaleAnimation(
              scale: 0.8,
              child: FadeInAnimation(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: isDesktop ? 120 : isTablet ? 100 : 80,
                        height: isDesktop ? 120 : isTablet ? 100 : 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.tealPrimary.withOpacity(0.3),
                              AppColors.tealPrimary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealPrimary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.build_circle,
                          size: isDesktop ? 60 : isTablet ? 50 : 40,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Animated title
        AnimationConfiguration.staggeredList(
          position: 1,
          duration: const Duration(milliseconds: 1000),
          delay: const Duration(milliseconds: 300),
          child: SlideAnimation(
            verticalOffset: 50,
            child: FadeInAnimation(
              child: AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Welcome to\nMechFind',
                    textAlign: TextAlign.center,
                    textStyle: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: isDesktop ? 48 : isTablet ? 40 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.tealPrimary.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ],
                totalRepeatCount: 1,
                displayFullTextOnTap: true,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Subtitle
        AnimationConfiguration.staggeredList(
          position: 2,
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 800),
          child: SlideAnimation(
            verticalOffset: 30,
            child: FadeInAnimation(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Your trusted partner for automotive assistance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions({required bool isTablet, required bool isDesktop}) {
    final actions = [
      ActionData(
        icon: Icons.search,
        title: 'Find Mechanics',
        subtitle: 'Locate nearby services',
        color: AppColors.tealPrimary,
        route: '/findMechanics',
      ),
      ActionData(
        icon: Icons.emergency,
        title: 'Emergency Help',
        subtitle: 'Quick roadside assistance',
        color: AppColors.orangePrimary,
        route: '/emergency',
      ),
      ActionData(
        icon: Icons.history,
        title: 'Service History',
        subtitle: 'Track your repairs',
        color: AppColors.greenPrimary,
        route: '/history',
      ),
    ];

    return AnimatedBuilder(
      animation: _cardScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDesktop) 
                Row(
                  children: actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: QuickActionCard(
                          action: action,
                          index: index,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                ...actions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final action = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: QuickActionCard(
                      action: action,
                      index: index,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions({required bool isTablet, required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 1500),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: ModernActionButton(
                    text: 'Get Started',
                    icon: Icons.rocket_launch,
                    isPrimary: true,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onPressed: () {
                      Navigator.pushNamed(context, '/signin');
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimationConfiguration.staggeredList(
              position: 1,
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 1700),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: ModernActionButton(
                    text: 'Browse',
                    icon: Icons.explore,
                    isPrimary: false,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onPressed: () {
                      Navigator.pushNamed(context, '/userHome');
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data classes and widgets
class ActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  ActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

class QuickActionCard extends StatefulWidget {
  final ActionData action;
  final int index;
  final bool isTablet;
  final bool isDesktop;

  const QuickActionCard({
    super.key,
    required this.action,
    required this.index,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.2,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: widget.index,
      duration: const Duration(milliseconds: 600),
      delay: Duration(milliseconds: 1200 + (widget.index * 200)),
      child: SlideAnimation(
        horizontalOffset: widget.index.isEven ? -50 : 50,
        child: FadeInAnimation(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: GestureDetector(
                  onTapDown: (_) => _hoverController.forward(),
                  onTapUp: (_) {
                    _hoverController.reverse();
                    Navigator.pushNamed(context, widget.action.route);
                  },
                  onTapCancel: () => _hoverController.reverse(),
                  child: Container(
                    padding: EdgeInsets.all(widget.isDesktop ? 20 : widget.isTablet ? 16 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.action.color.withOpacity(_glowAnimation.value * 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.action.color.withOpacity(_glowAnimation.value * 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: widget.isDesktop ? 50 : widget.isTablet ? 45 : 40,
                          height: widget.isDesktop ? 50 : widget.isTablet ? 45 : 40,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                widget.action.color.withOpacity(0.3),
                                widget.action.color.withOpacity(0.1),
                              ],
                              stops: const [0.0, 1.0],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.action.color.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            widget.action.icon,
                            color: widget.action.color,
                            size: widget.isDesktop ? 24 : widget.isTablet ? 22 : 20,
                          ),
                        ),
                        SizedBox(width: widget.isDesktop ? 16 : widget.isTablet ? 14 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.action.title,
                                style: TextStyle(
                                  fontFamily: AppFonts.primaryFont,
                                  color: Colors.white,
                                  fontSize: widget.isDesktop ? 18 : widget.isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.action.subtitle,
                                style: TextStyle(
                                  fontFamily: AppFonts.primaryFont,
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: widget.isDesktop ? 14 : widget.isTablet ? 13 : 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.5),
                          size: widget.isDesktop ? 18 : widget.isTablet ? 16 : 14,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ModernActionButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final bool isPrimary;
  final bool isTablet;
  final bool isDesktop;
  final VoidCallback onPressed;

  const ModernActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.isPrimary,
    required this.isTablet,
    required this.isDesktop,
    required this.onPressed,
  });

  @override
  State<ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<ModernActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: widget.isDesktop ? 52 : widget.isTablet ? 50 : 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isDesktop ? 26 : widget.isTablet ? 25 : 24),
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: [
                      AppColors.tealPrimary,
                      AppColors.tealSecondary,
                    ],
                  )
                : null,
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.tealPrimary.withOpacity(_glowAnimation.value * 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isPrimary ? Colors.transparent : Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.isDesktop ? 26 : widget.isTablet ? 25 : 24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: widget.isDesktop ? 8 : widget.isTablet ? 7 : 6),
                Icon(
                  widget.icon,
                  size: widget.isDesktop ? 18 : widget.isTablet ? 17 : 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
