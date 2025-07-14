import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mechfind/utils.dart';
import '../selected_role.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
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
  String? userImageUrl;

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
        emailRedirectTo: 'YOUR_REDIRECT_URL', // <-- Change to your app URL here
      );

      final user = signUpRes.user;

      if (user == null) {
        _showMessage('Sign up failed. Please try again.');
        setState(() => _loading = false);
        return;
      }

      // Show dialog telling user to check email for verification
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
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        hintText: hintText,
        hintStyle: AppTextStyles.label.copyWith(fontFamily: AppFonts.secondaryFont),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(fontFamily: AppFonts.secondaryFont),
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
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
        hintText: label,
        hintStyle: AppTextStyles.label.copyWith(fontFamily: AppFonts.secondaryFont),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(fontFamily: AppFonts.secondaryFont),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account', style: AppTextStyles.heading.copyWith(fontSize: FontSizes.heading)),
            const SizedBox(height: 8),
            Text('Join MechFind and get instant roadside assistance',
                style: AppTextStyles.body.copyWith(fontSize: FontSizes.subHeading, color: AppColors.textSecondary)),
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
                  backgroundColor: AppColors.primary,
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
                Text('Already have an account? ', style: AppTextStyles.body.copyWith(fontSize: FontSizes.body)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/signin'),
                  child: Text('Sign In',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      )),
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
