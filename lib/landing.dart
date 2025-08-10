import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'package:mechfind/utils.dart';
import 'user_home.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

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
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);
  }

  void _startAnimations() {
    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
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
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            _buildAnimatedBackground(),

            // Floating particles effect
            _buildFloatingParticles(),

            // Main content
            SafeArea(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildMainContent(isTablet: isTablet, isDesktop: isDesktop),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Rotating gears/tools in background
        ...List.generate(8, (index) {
          return AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              final angle = _rotationAnimation.value + (index * math.pi / 4);
              final radius = 150.0 + (index * 30);
              final size = MediaQuery.of(context).size;

              return Positioned(
                left: size.width / 2 + math.cos(angle) * radius - 15,
                top: size.height / 2 + math.sin(angle) * radius - 15,
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(
                    _getToolIcon(index),
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              );
            },
          );
        }),

        // Grid pattern overlay
        Positioned.fill(
          child: CustomPaint(
            painter: LandingGridPatternPainter(),
          ),
        ),
      ],
    );
  }

  IconData _getToolIcon(int index) {
    final icons = [
      Icons.build,
      Icons.settings,
      Icons.handyman,
      Icons.construction,
      Icons.engineering,
      Icons.precision_manufacturing,
      Icons.car_repair,
      Icons.home_repair_service,
    ];
    return icons[index % icons.length];
  }

  Widget _buildFloatingParticles() {
    return Stack(
      children: List.generate(20, (index) {
        return AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            final offset = Offset(
              math.sin(_rotationAnimation.value + index * 0.5) * 30,
              math.cos(_rotationAnimation.value + index * 0.3) * 20,
            );
            return Positioned(
              left: (index * 40.0) % MediaQuery.of(context).size.width + offset.dx,
              top: (index * 60.0) % MediaQuery.of(context).size.height + offset.dy,
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildMainContent({required bool isTablet, required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48.0 : isTablet ? 32.0 : 24.0,
          vertical: 8.0
      ),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: _buildHeroSection(isTablet: isTablet, isDesktop: isDesktop),
          ),
          Expanded(
            flex: 3,
            child: _buildFeaturesSection(isTablet: isTablet, isDesktop: isDesktop),
          ),
          _buildActionButtons(isTablet: isTablet, isDesktop: isDesktop),
        ],
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
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.tealPrimary.withOpacity(0.3),
                              AppColors.orangePrimary.withOpacity(0.2),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
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
                          size: isDesktop ? 80 : isTablet ? 70 : 60,
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

        const SizedBox(height: 20),

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
                    'MechFind',
                    textStyle: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: isDesktop ? 56 : isTablet ? 48 : 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.tealPrimary.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    speed: const Duration(milliseconds: 100),
                  ),
                ],
                totalRepeatCount: 1,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle
        AnimationConfiguration.staggeredList(
          position: 2,
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 800),
          child: SlideAnimation(
            verticalOffset: 30,
            child: FadeInAnimation(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  'Your Roadside Rescue Partner',
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection({required bool isTablet, required bool isDesktop}) {
    final features = [
      FeatureData(
        icon: Icons.location_on,
        text: 'Find nearby mechanics instantly',
        color: AppColors.tealPrimary,
      ),
      FeatureData(
        icon: Icons.people,
        text: 'Connect with trusted professionals',
        color: AppColors.orangePrimary,
      ),
      FeatureData(
        icon: Icons.shield,
        text: 'Emergency roadside assistance',
        color: AppColors.greenPrimary,
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isDesktop)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: features.asMap().entries.map((entry) {
              final feature = entry.value;
              return Expanded(
                child: ModernFeatureItem(
                  icon: feature.icon,
                  text: feature.text,
                  color: feature.color,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
              );
            }).toList(),
          )
        else
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 600),
              delay: Duration(milliseconds: 1200 + (index * 200)),
              child: SlideAnimation(
                horizontalOffset: index.isEven ? -50 : 50,
                child: FadeInAnimation(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ModernFeatureItem(
                      icon: feature.icon,
                      text: feature.text,
                      color: feature.color,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildActionButtons({required bool isTablet, required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: isDesktop ?
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 2000),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: GlowingButton(
                    text: 'Get Started',
                    primaryColor: AppColors.tealPrimary,
                    secondaryColor: AppColors.tealSecondary,
                    icon: Icons.rocket_launch,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onPressed: () {
                      Navigator.pushNamed(context, '/home');
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
              delay: const Duration(milliseconds: 2200),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: _buildSecondaryButton(isTablet: isTablet, isDesktop: isDesktop),
                ),
              ),
            ),
          ),
        ],
      ) :
      Column(
        children: [
          // Primary button
          AnimationConfiguration.staggeredList(
            position: 0,
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 2000),
            child: SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: GlowingButton(
                  text: 'Get Started',
                  primaryColor: AppColors.tealPrimary,
                  secondaryColor: AppColors.tealSecondary,
                  icon: Icons.rocket_launch,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  onPressed: () {
                    Navigator.pushNamed(context, '/home');
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Secondary button
          AnimationConfiguration.staggeredList(
            position: 1,
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 2200),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: _buildSecondaryButton(isTablet: isTablet, isDesktop: isDesktop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({required bool isTablet, required bool isDesktop}) {
    return Container(
      width: double.infinity,
      height: isDesktop ? 52 : isTablet ? 50 : 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isDesktop ? 26 : isTablet ? 25 : 24),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserHomePage(isGuest: true)),
          );
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 26 : isTablet ? 25 : 24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Browse as Guest',
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: Colors.white.withOpacity(0.9),
                fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: isDesktop ? 10 : isTablet ? 9 : 8),
            Icon(
              Icons.visibility,
              color: Colors.white.withOpacity(0.7),
              size: isDesktop ? 22 : isTablet ? 21 : 20,
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureData {
  final IconData icon;
  final String text;
  final Color color;

  FeatureData({
    required this.icon,
    required this.text,
    required this.color,
  });
}

class ModernFeatureItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isTablet;
  final bool isDesktop;

  const ModernFeatureItem({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.isTablet = false,
    this.isDesktop = false,
  });

  @override
  State<ModernFeatureItem> createState() => _ModernFeatureItemState();
}

class _ModernFeatureItemState extends State<ModernFeatureItem>
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
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _hoverController.forward(),
            onTapUp: (_) => _hoverController.reverse(),
            onTapCancel: () => _hoverController.reverse(),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: widget.isDesktop ? 20 : widget.isTablet ? 18 : 16,
                  vertical: widget.isDesktop ? 16 : widget.isTablet ? 14 : 12
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.color.withOpacity(_glowAnimation.value * 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withOpacity(0.3),
                          widget.color.withOpacity(0.1),
                        ],
                        stops: [0.0, 1.0],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.isDesktop ? 24 : widget.isTablet ? 22 : 20,
                    ),
                  ),
                  SizedBox(width: widget.isDesktop ? 16 : widget.isTablet ? 14 : 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: Colors.white.withOpacity(0.9),
                        fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: widget.color.withOpacity(0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlowingButton extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isTablet;
  final bool isDesktop;

  const GlowingButton({
    super.key,
    required this.text,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.onPressed,
    this.isTablet = false,
    this.isDesktop = false,
  });

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton>
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
            gradient: LinearGradient(
              colors: [
                widget.primaryColor,
                widget.secondaryColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(
                    0.3 + (_glowAnimation.value * 0.2)
                ),
                blurRadius: 20,
                spreadRadius: _glowAnimation.value * 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
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
                    fontSize: widget.isDesktop ? 18 : widget.isTablet ? 17 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: widget.isDesktop ? 8 : widget.isTablet ? 7 : 6),
                Icon(
                  widget.icon,
                  size: widget.isDesktop ? 20 : widget.isTablet ? 19 : 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LandingGridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 80.0;

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