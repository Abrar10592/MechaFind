import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageToggleWidget extends StatefulWidget {
  final VoidCallback? onLanguageChanged;

  const LanguageToggleWidget({
    super.key,
    this.onLanguageChanged,
  });

  @override
  State<LanguageToggleWidget> createState() => _LanguageToggleWidgetState();
}

class _LanguageToggleWidgetState extends State<LanguageToggleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool isEnglish = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial language state
    isEnglish = context.locale.languageCode == 'en';
    if (!isEnglish) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleLanguage() async {
    final newLanguage = isEnglish ? 'bn' : 'en';
    final newLocale = Locale(newLanguage);

    try {
      // Save language preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang_code', newLanguage);

      // Change language
      await context.setLocale(newLocale);

      // Update animation
      setState(() {
        isEnglish = !isEnglish;
      });

      if (isEnglish) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLanguage == 'en' 
                ? 'Language changed to English' 
                : 'ভাষা বাংলায় পরিবর্তিত হয়েছে',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      // Callback to parent widget
      if (widget.onLanguageChanged != null) {
        widget.onLanguageChanged!();
      }
    } catch (e) {
      print('Error changing language: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglish 
                ? 'Failed to change language'
                : 'ভাষা পরিবর্তন করতে ব্যর্থ',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: Container(
        width: 80,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey[300],
          border: Border.all(
            color: const Color(0xFF06B6D4),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Background
            Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF06B6D4).withOpacity(0.1),
                    const Color(0xFF0891B2).withOpacity(0.1),
                  ],
                ),
              ),
            ),
            
            // Sliding indicator
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Positioned(
                  left: _slideAnimation.value * 42,
                  top: 2,
                  child: Container(
                    width: 36,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF06B6D4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isEnglish ? 'EN' : 'বাং',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Labels
            Positioned(
              left: 6,
              top: 8,
              child: Text(
                'EN',
                style: TextStyle(
                  color: isEnglish ? Colors.white : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 8,
              child: Text(
                'বাং',
                style: TextStyle(
                  color: !isEnglish ? Colors.white : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
