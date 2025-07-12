import 'package:flutter/material.dart';
import '../utils.dart'; // Adjust the path if needed

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
            Text(
              'Create Account',
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.heading,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join MechFind and get instant roadside assistance',
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.subHeading,
                color: AppColors.textSecondary,
                fontFamily: AppFonts.secondaryFont,
              ),
            ),
            const SizedBox(height: 32),

            _buildTextField(Icons.person_outline, 'Full Name'),
            const SizedBox(height: 16),

            _buildTextField(Icons.email_outlined, 'Email address'),
            const SizedBox(height: 16),

            _buildTextField(Icons.phone_outlined, 'Phone Number'),
            const SizedBox(height: 16),

            _buildPasswordField(
              obscureText: _obscurePassword,
              label: 'Password',
              onToggle: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 16),

            _buildPasswordField(
              obscureText: _obscureConfirmPassword,
              label: 'Confirm Password',
              onToggle: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Handle account creation logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Create Account',
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.body,
                    fontFamily: AppFonts.secondaryFont,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/signin');
                  },
                  child: Text(
                    'Sign In',
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

  Widget _buildTextField(IconData icon, String hintText) {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        hintText: hintText,
        hintStyle: AppTextStyles.label.copyWith(
          fontFamily: AppFonts.secondaryFont,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(
        fontFamily: AppFonts.secondaryFont,
      ),
    );
  }

  Widget _buildPasswordField({
    required bool obscureText,
    required String label,
    required VoidCallback onToggle,
  }) {
    return TextField(
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
        hintStyle: AppTextStyles.label.copyWith(
          fontFamily: AppFonts.secondaryFont,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTextStyles.body.copyWith(
        fontFamily: AppFonts.secondaryFont,
      ),
    );
  }
}
