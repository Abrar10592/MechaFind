import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove backgroundColor, use image background instead
      body: Stack(
        children: [
          // 1. Background image (replace with your image path)
          Positioned.fill(
            child: Image.asset(
              'assets/landing_bg.png', // Update to match your actual filename and path
              fit: BoxFit.cover,
            ),
          ),
          // 2. Semi-transparent overlay for better text/icon contrast (adjust opacity if needed)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.40),
            ),
          ),
          // 3. Main page content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.build,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'MechFind',
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: FontSizes.heading,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Roadside Rescue Partner',
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: FontSizes.subHeading,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const FeatureItem(icon: Icons.location_on, text: 'Find nearby mechanics instantly'),
                  const FeatureItem(icon: Icons.people, text: 'Connect with trusted professionals'),
                  const FeatureItem(icon: Icons.shield, text: 'Emergency roadside assistance'),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/home');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: AppColors.primary,
                        fontSize: FontSizes.subHeading,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/userHome');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Browse as Guest',
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: Colors.white,
                        fontSize: FontSizes.subHeading,
                        fontWeight: FontWeight.bold,
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
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: Colors.white,
                fontSize: FontSizes.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
