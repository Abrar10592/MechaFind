import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mechfind/utils.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_enter_email_password'))),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('login_failed'))),
        );
        setState(() => _loading = false);
        return;
      }

      if (user.emailConfirmedAt == null) {
        await supabase.auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('please_verify_email'))),
        );
        setState(() => _loading = false);
        return;
      }

      final userId = user.id;

      // Fetch user role from users table
      final userRecord = await supabase.from('users').select('role').eq('id', userId).maybeSingle();

      if (userRecord == null) {
        await supabase.auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('user_data_not_found'))),
        );
        setState(() => _loading = false);
        return;
      }

      final String role = userRecord['role'];

      // Store user role in SharedPreferences for session persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      if (role == 'mechanic') {
        final mechanicRecord = await supabase.from('mechanics').select().eq('id', userId).maybeSingle();
        if (mechanicRecord == null) {
          await supabase.from('mechanics').insert({
            'id': userId,
            'location_x': null,
            'location_y': null,
            
            'rating': 0.0,
            'image_url': null,
          });
        }
        Navigator.pushReplacementNamed(context, '/mechanicHome');
      } else {
        Navigator.pushReplacementNamed(context, '/userHome');
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("auth_error")} ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("unexpected_error")} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'YOUR_REDIRECT_URL', // Replace with your redirect URL
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_enter_email_reset'))),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'YOUR_REDIRECT_URL', // Replace with your redirect URL
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('password_reset_email_sent'))),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField({
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: AppTextStyles.label.copyWith(
          fontFamily: AppFonts.secondaryFont,
          color: Colors.white60,
        ),
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(
        color: Colors.white,
        fontFamily: AppFonts.secondaryFont,
      ),
      cursorColor: AppColors.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              tr('welcome_back_signin'),
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.heading,
                fontFamily: AppFonts.primaryFont,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('sign_in_to_account'),
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.body,
                color: Colors.white70,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              icon: Icons.email_outlined,
              hintText: tr('email_address'),
              controller: _emailController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              icon: Icons.lock_outline,
              hintText: tr('password'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _resetPassword,
                child: Text(
                  tr('forgot_password'),
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        tr('sign_in'),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: FontSizes.subHeading,
                          color: Colors.white,
                          fontFamily: AppFonts.primaryFont,
                        ),
                      ),
              ),
            ),
           const SizedBox(height: 16),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr('dont_have_account'),
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white70,
                    fontSize: FontSizes.body,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/role'),
                  child: Text(
                    ' ${tr("sign_up")}',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppFonts.primaryFont,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}