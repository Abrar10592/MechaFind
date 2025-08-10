import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import '../onboarding/onboarding_screen.dart';
import '../../landing.dart';
import '../../user_home.dart';
import '../../mechanic/mechanic.dart';
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _radarController;
  late AnimationController _iconController;
  late AnimationController _gearController;
  late AnimationController _loadingController;
  late AnimationController _textGlowController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _radarAnimation;
  late Animation<double> _iconMorphAnimation;
  late Animation<double> _gearRotationAnimation;
  late Animation<double> _loadingAnimation;
  late Animation<double> _textGlowAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Main fade and scale controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Radar waves controller
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Icon morphing controller
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    // Gear rotation controller
    _gearController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    
    // Loading controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Text glow controller
    _textGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Setup animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
    
    _radarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );
    
    _iconMorphAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
    
    _gearRotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _gearController, curve: Curves.linear),
    );
    
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
    
    _textGlowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _textGlowController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _radarController.repeat();
    _iconController.repeat();
    _gearController.repeat();
    _loadingController.repeat();
    _textGlowController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 6));

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      // Check if user is already logged in
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (mounted) {
        if (!hasSeenOnboarding) {
          // First time user - show onboarding
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        } else if (currentUser != null) {
          // User is logged in - check their role and navigate appropriately
          await _navigateBasedOnUserRole();
        } else {
          // User has seen onboarding but not logged in - show landing page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPage()),
          );
        }
      }
    } catch (e) {
      print('Error during splash initialization: $e');
      if (mounted) {
        // On error, show onboarding or landing page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  Future<void> _navigateBasedOnUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'mechanic') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Mechanic()),
        );
      } else if (userRole == 'user') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHomePage()),
        );
      } else {
        // Role not set, redirect to landing page to choose role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    } catch (e) {
      print('Error getting user role: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandingPage()),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _fadeController.dispose();
    _radarController.dispose();
    _iconController.dispose();
    _gearController.dispose();
    _loadingController.dispose();
    _textGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Dark slate
              Color(0xFF1E293B), // Slate 800
              Color(0xFF0F4A5F), // Dark cyan
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background floating gears
            _buildBackgroundGears(),
            
            // Main content
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildMainContent(),
                  ),
                );
              },
            ),
            
            // Bottom overlay gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0F172A).withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGears() {
    return Stack(
      children: [
        // Gear 1 - Top right
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          right: MediaQuery.of(context).size.width * 0.1,
          child: AnimatedBuilder(
            animation: _gearRotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _gearRotationAnimation.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFF06B6D4),
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
        
        // Gear 2 - Bottom left
        Positioned(
          top: MediaQuery.of(context).size.height * 0.7,
          left: MediaQuery.of(context).size.width * 0.15,
          child: AnimatedBuilder(
            animation: _gearRotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_gearRotationAnimation.value * 0.8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFF06B6D4),
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ),
        
        // Gear 3 - Top left
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: MediaQuery.of(context).size.width * 0.05,
          child: AnimatedBuilder(
            animation: _gearRotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _gearRotationAnimation.value * 1.2,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFFF97316),
                    size: 15,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Radar waves with central icon
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar waves
                AnimatedBuilder(
                  animation: _radarAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.5 + (_radarAnimation.value * 1.5),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF06B6D4).withOpacity(
                              0.8 - (_radarAnimation.value * 0.8),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Central icon with morphing animation
                AnimatedBuilder(
                  animation: _iconMorphAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _iconMorphAnimation.value * math.pi * 2,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF06B6D4),
                              Color(0xFF0891B2),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF06B6D4).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _iconMorphAnimation.value > 0.5 
                              ? Icons.location_on_rounded 
                              : Icons.build_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // App title with glow effect
          AnimatedBuilder(
            animation: _textGlowAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _textGlowAnimation.value,
                child: Column(
                  children: [
                    Text(
                      'MechFind',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF06B6D4).withOpacity(_textGlowAnimation.value),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'find_your_mechanic'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 80),
          
          // Loading indicator
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Container(
          width: 200,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedBuilder(
            animation: _loadingAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 200 * _loadingAnimation.value,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF06B6D4),
                        Color(0xFF0891B2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Initializing...',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
