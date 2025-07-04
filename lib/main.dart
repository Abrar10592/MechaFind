import 'package:flutter/material.dart';
import 'home.dart';
import 'signup.dart';
import 'signin.dart';
import 'role.dart';

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
        '/': (context) => WelcomePage(),
        '/signup': (context) => SignUpPage(),
        '/signin': (context) => SignInPage(),
        '/role': (context) => RoleSelectionPage(),
        //'/create_account': (context) => CreateAccountPage(),
      },
    );
  }
}
