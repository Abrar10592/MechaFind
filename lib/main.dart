import 'package:flutter/material.dart';
import 'home.dart';
import 'signup.dart';
import 'signin.dart';
import 'role.dart';
import 'user_home.dart';
import 'landing.dart';

// Suppose you will create this page

void main() {
  runApp(MechFindApp());
}

class MechFindApp extends StatelessWidget {
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
        //'/create_account': (context) => CreateAccountPage(),
      },
    );
  }
}
