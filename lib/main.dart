import 'package:flutter/material.dart';
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
