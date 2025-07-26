import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/landing_bg.png', // Use your asset path here
              fit: BoxFit.cover,
            ),
          ),
          // Optional dark overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.40),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(
                    'Welcome to\nMechFind',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: FontSizes.heading,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect with mechanics and get roadside\nassistance when you need it most',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: FontSizes.body,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signin');
                    },
                    icon: const Icon(Icons.login),
                    label: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: FontSizes.subHeading,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/role');
                    },
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: FontSizes.subHeading,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.white),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/userHome');
                    },
                    child: const Text(
                      'Continue as Guest',
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        fontSize: FontSizes.body,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
