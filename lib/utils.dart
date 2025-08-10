import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color.fromARGB(255, 21, 24, 53); // Deep navy blue
  static const accent = Color(0xFF00ACC1); // Electric teal
  static const secondary = Color(0xFFFF6F00); // Vibrant orange
  static const background = Color(0xFFF5F8FA);
  static const danger = Color(0xFFE53935);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color.fromARGB(255, 121, 120, 120);
  static const textlight= Color.fromARGB(255, 255, 255, 255);
  
  // New gradient colors for onboarding
  static const gradientStart = Color(0xFF1A237E);
  static const gradientEnd = Color(0xFF283593);
  static const tealPrimary = Color(0xFF00ACC1);
  static const tealSecondary = Color(0xFF0277BD);
  static const orangePrimary = Color(0xFFFF6F00);
  static const orangeSecondary = Color(0xFFE65100);
  static const greenPrimary = Color(0xFF2E7D32);
  static const greenSecondary = Color(0xFF1B5E20);
}

class AppTextStyles {
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}


class AppFonts {
  static const String primaryFont = 'Poppins';
  static const String secondaryFont = 'Roboto';
}

class FontSizes {
  static const double heading = 24.0;
  static const double subHeading = 18.0;
  static const double body = 14.0;
  static const double caption = 12.0;
}
