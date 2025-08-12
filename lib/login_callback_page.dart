import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/user_service.dart';

class LoginCallbackPage extends StatefulWidget {
  const LoginCallbackPage({super.key});

  @override
  State<LoginCallbackPage> createState() => _LoginCallbackPageState();
}

class _LoginCallbackPageState extends State<LoginCallbackPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _completeSignUp();
  }

  Future<void> _completeSignUp() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    print('user.id: ${user?.id}');

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('temp_full_name');
    final email = prefs.getString('temp_email');
    final phone = prefs.getString('temp_phone');
    final role = prefs.getString('temp_role');

    if (fullName == null || email == null || phone == null || role == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Check if user already exists to prevent duplicate insert
      final userExists = await UserService.userExists(user.id);

      if (!userExists) {
        final success = await UserService.createUser(
          id: user.id,
          fullName: fullName,
          email: email,
          phone: phone,
          role: role,
        );

        if (!success) {
          print('Failed to create user record in database');
        }
      }

      // Clean up temporary preferences
      await prefs.remove('temp_full_name');
      await prefs.remove('temp_email');
      await prefs.remove('temp_phone');
      await prefs.remove('temp_role');

      // Navigate to appropriate home screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error in signup completion: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading ? const CircularProgressIndicator() : const Text('Login failed.'),
      ),
    );
  }
}
