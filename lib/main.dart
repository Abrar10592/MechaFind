import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'find_mechanics.dart';
import 'home.dart';
import 'signup.dart';
import 'signin.dart';
import 'role.dart';
import 'user_home.dart';
import 'landing.dart';
import 'screens/history/history_page.dart';
import 'screens/settings/settings_profile_screen.dart';

void main() {
  runApp(MechFindApp());
}

class MechFindApp extends StatelessWidget {
  const MechFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechFind',
       theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.heading,
          bodyMedium: AppTextStyles.body,
          labelLarge: AppTextStyles.label,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(),
        '/signup': (context) => SignUpPage(),
        '/signin': (context) => SignInPage(),
        '/role': (context) => RoleSelectionPage(),
        '/userHome': (context) => UserHomePage(),
        '/home': (context) => WelcomePage(),
        '/find-mechanics': (context) => const FindMechanicsPage(),
        '/history': (context) => const HistoryPage(),
        '/settings': (context) => const SettingsProfileScreen(),
        //'/create_account': (context) => CreateAccountPage(),
      },
    );
  }
}
