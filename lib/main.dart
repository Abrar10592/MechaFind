import 'package:flutter/material.dart';
import 'package:mechfind/mechanic/mechanic.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'landing.dart';
import 'signup.dart';
import 'signin.dart';
import 'role.dart';
import 'user_home.dart';
import 'find_mechanics.dart';
import 'home.dart';
import 'screens/history/history_page.dart';
import 'screens/settings/settings_profile_screen.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ygmvmhsbxipuykpjrfgj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlnbXZtaHNieGlwdXlrcGpyZmdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwMjU5OTIsImV4cCI6MjA2NjYwMTk5Mn0.0FwAnum-j6Js5y8IPNL8cjSZchgFBcUabvhdIE_iwfI',

  );

  runApp(const MechFindApp());
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
        '/mechanicHome': (context) => Mechanic(),
        '/home': (context) => WelcomePage(),
        '/find-mechanics': (context) => const FindMechanicsPage(),
        '/history': (context) => const HistoryPage(),
        '/settings': (context) => const SettingsProfileScreen(),
      },
    );
  }
}
