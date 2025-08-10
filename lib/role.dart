import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'selected_role.dart'; // Import the global variable

// Import your utilities—update this path if necessary
import 'utils.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Your Role',
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: FontSizes.heading,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Select how you want to use MechFind',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontFamily: AppFonts.secondaryFont,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 36),
            RoleCard(
              icon: Icons.directions_car,
              title: 'Vehicle Owner',
              description: 'Get help when your vehicle breaks down. Connect with nearby mechanics instantly.',
              bulletPoints: [
                'Emergency assistance',
                'Find nearby mechanics',
                'Real-time tracking',
              ],
              onTap: () async {
                selectedRole = 'user';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_role', 'user');
                Navigator.pushNamed(context, '/signup');
              },
              cardColor: Colors.white.withOpacity(0.07),
              iconColor: AppColors.accent,
              textColor: Colors.white,
              bulletColor: AppColors.accent,
            ),
            const SizedBox(height: 24),
            RoleCard(
              icon: Icons.build,
              title: 'Mechanic / Workshop',
              description: 'Provide roadside assistance and grow your business by helping drivers in need.',
              bulletPoints: [
                'Receive help requests',
                'Manage availability',
                'Build your reputation',
              ],
              onTap: () async {
                selectedRole = 'mechanic';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_role', 'mechanic');
                Navigator.pushNamed(context, '/signup');
              },
              cardColor: Colors.white.withOpacity(0.07),
              iconColor: AppColors.accent,
              textColor: Colors.white,
              bulletColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bulletPoints;
  final VoidCallback onTap;
  final Color cardColor;
  final Color iconColor;
  final Color textColor;
  final Color bulletColor;

  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.bulletPoints,
    required this.onTap,
    required this.cardColor,
    required this.iconColor,
    required this.textColor,
    required this.bulletColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.8),
                child: Icon(icon, size: 38, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.heading.copyWith(
                  fontFamily: AppFonts.primaryFont,
                  fontSize: FontSizes.subHeading + 2,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white70,
                  fontFamily: AppFonts.secondaryFont,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: bulletPoints
                    .map(
                      (point) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        Text('• ', style: TextStyle(color: bulletColor, fontSize: 18)),
                        Expanded(
                          child: Text(
                            point,
                            style: AppTextStyles.body.copyWith(
                              color: textColor,
                              fontSize: FontSizes.body + 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
