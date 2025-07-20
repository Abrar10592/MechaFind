import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart'; // Update if your actual utils path differs

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image for portrait display
          Image.asset(
            'assets/landing_bg.png',
            fit: BoxFit.cover, // Fills background, crops sides (portrait-optimized)
            alignment: Alignment.topCenter, // Keeps the top centered if cropped
          ),
          // Semi-transparent overlay for readability
          Container(
            color: Colors.black.withOpacity(0.65),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Top spacing for visual balance
                    const Icon(
                      Icons.build,
                      size: 100,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'MechFind',
                      textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: FontSizes.subHeading,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const FeatureItem(
                        icon: Icons.location_on, text: 'Find nearby mechanics instantly'),
                    const FeatureItem(
                        icon: Icons.people, text: 'Connect with trusted professionals'),
                    const FeatureItem(
                        icon: Icons.shield, text: 'Emergency roadside assistance'),
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
                    const SizedBox(height: 24),
                  ],
                ),
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
