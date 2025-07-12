import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color.fromARGB(255, 21, 24, 53);
  static const accent = Color(0xFF00ACC1);
  static const background = Color(0xFFF5F8FA);
  static const danger = Color(0xFFE53935);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
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
