import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mechfind/utils.dart';
import '../selected_role.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill all required fields');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match');
      return;
    }

    if (selectedRole == null) {
      _showMessage('Please select a role first');
      return;
    }

    setState(() => _loading = true);

    try {
      final signUpRes = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'YOUR_REDIRECT_URL',
      );

      final user = signUpRes.user;

      if (user == null) {
        _showMessage('Sign up failed. Please try again.');
        setState(() => _loading = false);
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Verify Your Email'),
          content: const Text(
            'A verification email has been sent to your email address. '
                'Please verify your email to activate your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    } on AuthException catch (e) {
      _showMessage('Auth error: ${e.message}');
    } catch (e) {
      _showMessage('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTextField(IconData icon, String hintText, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hintText,
        hintStyle: AppTextStyles.label.copyWith(
          fontFamily: AppFonts.secondaryFont,
          color: Colors.white60,
        ),
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(
        fontFamily: AppFonts.secondaryFont,
        color: Colors.white,
      ),
      cursorColor: AppColors.accent,
    );
  }

  Widget _buildPasswordField({
    required bool obscureText,
    required String label,
    required TextEditingController controller,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: onToggle,
        ),
        hintText: label,
        hintStyle: AppTextStyles.label.copyWith(
          fontFamily: AppFonts.secondaryFont,
          color: Colors.white60,
        ),
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(
        fontFamily: AppFonts.secondaryFont,
        color: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Create Account',
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.heading,
                color: Colors.white,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join MechFind and get instant roadside assistance',
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.subHeading,
                color: Colors.white70,
                fontFamily: AppFonts.secondaryFont,
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(Icons.person_outline, 'Full Name', _fullNameController),
            const SizedBox(height: 16),
            _buildTextField(Icons.email_outlined, 'Email address', _emailController),
            const SizedBox(height: 16),
            _buildTextField(Icons.phone_outlined, 'Phone Number', _phoneController),
            const SizedBox(height: 16),
            _buildPasswordField(
              obscureText: _obscurePassword,
              label: 'Password',
              controller: _passwordController,
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              obscureText: _obscureConfirmPassword,
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Create Account',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: FontSizes.subHeading,
                      color: Colors.white,
                      fontFamily: AppFonts.primaryFont,
                    )),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.body,
                    color: Colors.white70,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/signin'),
                  child: Text(
                    'Sign In',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: FontSizes.body,
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
