import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../utils.dart';
import '../../widgets/bottom_navbar.dart';
import '../../services/user_service.dart';

class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDate;
  List<String> _vehicleModels = [];
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('unable_to_load_profile_data'))),
          );
        }
        return;
      }

      setState(() {
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phone;
        
        // Handle date of birth
        _selectedDate = profile.dateOfBirth;
        
        // Handle vehicle models array
        _vehicleModels = List<String>.from(profile.vehicleModels);
        
        // Handle profile image URL
        _profileImageUrl = profile.imageUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr("error_loading_profile")} $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Colors.white,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative elements
              Positioned(
                top: -100,
                right: -100,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Main content
              CustomScrollView(
                slivers: [
                  // Enhanced App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/userHome', (route) => false);
                        },
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.1),
                              child: IconButton(
                                icon: _isLoading 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.save, color: Colors.white),
                                onPressed: _isLoading ? null : _saveProfile,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decorative circles
                            Positioned(
                              top: 20,
                              right: 30,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              right: 80,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                            ),
                            // Title
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr("profile_and"),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: FontSizes.body,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tr("settings"),
                                      style: AppTextStyles.heading.copyWith(
                                        color: Colors.white,
                                        fontSize: FontSizes.heading,
                                        fontFamily: AppFonts.primaryFont,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Content
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _isLoading && _nameController.text.isEmpty
                          ? _buildEnhancedShimmerLoading()
                          : Padding(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Enhanced Profile Picture Section
                                    _buildEnhancedProfilePictureSection(),
                                    
                                    const SizedBox(height: 24),

                                    // Enhanced Personal Info Section
                                    _buildEnhancedPersonalInfoSection(),

                                    const SizedBox(height: 24),

                                    // Enhanced Vehicle Info Section
                                    _buildEnhancedVehicleInfoSection(),

                                    const SizedBox(height: 24),

                                    // Enhanced App Settings Section
                                    _buildEnhancedAppSettingsSection(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4, // Profile/Settings tab index
        onTap: (index) {
          if (index == 4) return; // Already on Settings
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(context, '/userHome', (route) => false);
              break;
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushNamed(context, '/messages');
              break;
            case 3:
              Navigator.pushNamed(context, '/history');
              break;
          }
        },
      ),
    );
  }



  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _addVehicle() async {
    if (_vehicleController.text.isNotEmpty) {
      final newVehicle = _vehicleController.text.trim();
      
      // Since the schema only supports one vehicle (veh_model is text, not array),
      // Add the new vehicle to the list (don't clear existing ones)
      setState(() {
        if (!_vehicleModels.contains(newVehicle)) {
          _vehicleModels.add(newVehicle);
        }
        _vehicleController.clear();
      });

      // Update database immediately with the entire list
      try {
        final success = await UserService.updateVehicleModel(_vehicleModels);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('failed_to_save_vehicle')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        // Error handling without debug print
      }
    }
  }

  Future<void> _removeVehicle(String vehicle) async {
    setState(() {
      _vehicleModels.remove(vehicle);
    });

    // Update database immediately with the updated list (not empty array)
    try {
      final success = await UserService.updateVehicleModel(_vehicleModels);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_to_remove_vehicle')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Error handling without debug print
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        
        // Upload profile image if selected
        if (_profileImage != null) {
          try {
            final bytes = await _profileImage!.readAsBytes();
            final uploadedImageUrl = await UserService.uploadProfileImage(
              _profileImage!.path, 
              bytes
            );
            imageUrl = uploadedImageUrl;
          } catch (uploadError) {
            // Continue without image update
          }
        }

        // Prepare update data - only update fields that have values
        Map<String, dynamic> updateData = {};

        // Only update name if it's not empty
        if (_nameController.text.trim().isNotEmpty) {
          updateData['full_name'] = _nameController.text.trim();
        }

        // Only update phone if it's not empty  
        if (_phoneController.text.trim().isNotEmpty) {
          updateData['phone'] = _phoneController.text.trim();
        }

        // Add date of birth if selected
        if (_selectedDate != null) {
          updateData['dob'] = _selectedDate!.toIso8601String().split('T')[0]; // Date only
        }

        // Handle vehicle models array - only update if there are vehicles
        String pendingVehicle = _vehicleController.text.trim();
        if (pendingVehicle.isNotEmpty && !_vehicleModels.contains(pendingVehicle)) {
          _vehicleModels.add(pendingVehicle);
          _vehicleController.clear(); // Clear the input after adding
        }
        
        // Only update vehicle models if there are any
        if (_vehicleModels.isNotEmpty) {
          updateData['veh_model'] = _vehicleModels;
        }

        // Add image URL if uploaded
        if (imageUrl != null) {
          updateData['image_url'] = imageUrl;
        }

        // Only proceed with update if there's something to update
        if (updateData.isNotEmpty) {
          // Update user data in database using UserService
          final success = await UserService.updateUserProfile(updateData);

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('profile_updated_successfully')),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('failed_to_update_profile')),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // No changes to save
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('no_changes_to_save')),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tr("error_saving_profile")} $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }



  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('select_language'), style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Row(
                children: [
                  Text('🇺🇸', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 12),
                  Text(tr('english'), style: AppTextStyles.body),
                ],
              ),
              value: 'en',
              groupValue: context.locale.languageCode,
              onChanged: (value) => _changeLanguage(value!),
              activeColor: AppColors.primary,
            ),
            RadioListTile<String>(
              title: Row(
                children: [
                  Text('🇧🇩', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 12),
                  Text(tr('bangla'), style: AppTextStyles.body),
                ],
              ),
              value: 'bn',
              groupValue: context.locale.languageCode,
              onChanged: (value) => _changeLanguage(value!),
              activeColor: AppColors.primary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('${tr("cancel")} / ${tr("cancel")}'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang_code', languageCode);
    
    final newLocale = Locale(languageCode);
    await context.setLocale(newLocale);
    
    Navigator.pop(context); // Close dialog
    
    setState(() {}); // Rebuild to reflect language change
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageCode == 'en' 
            ? tr('language_changed_to_english') 
            : tr('language_changed_to_bangla')
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('logout'), style: AppTextStyles.heading),
        content: Text(tr('are_you_sure_logout'), style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: Text(tr('logout')),
          ),
        ],
      ),
    );
  }

  // Enhanced Loading State
  Widget _buildEnhancedShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header shimmer
                      Container(
                        height: 20,
                        width: double.infinity * 0.4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                            end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade100,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Content shimmer
                      Container(
                        height: 16,
                        width: double.infinity * 0.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                            end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade100,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Container(
                        height: 16,
                        width: double.infinity * 0.6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                            end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade100,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  // Enhanced Profile Picture Section
  Widget _buildEnhancedProfilePictureSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            tr('profile_picture'),
            style: AppTextStyles.heading.copyWith(
              fontSize: FontSizes.subHeading,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.05),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImage != null 
                              ? FileImage(_profileImage!) 
                              : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null),
                          child: _profileImage == null && _profileImageUrl == null 
                              ? Icon(
                                  Icons.person, 
                                  size: 60, 
                                  color: AppColors.primary.withOpacity(0.7),
                                ) 
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.transparent,
                      child: const Icon(
                        Icons.camera_alt, 
                        size: 18, 
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            tr('tap_to_change_profile_picture'),
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Personal Info Section
  Widget _buildEnhancedPersonalInfoSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.2),
                        AppColors.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('personal_information'),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: FontSizes.subHeading,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildEnhancedInput(_nameController, tr('full_name'), Icons.person_outline, isRequired: true),
            const SizedBox(height: 16),
            
            _buildEnhancedInput(_phoneController, tr('phone_number'), Icons.phone_outlined),
            const SizedBox(height: 16),
            
            _buildEnhancedDateSelector(),
          ],
        ),
      ),
    );
  }

  // Enhanced Vehicle Info Section
  Widget _buildEnhancedVehicleInfoSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.tealPrimary.withOpacity(0.2),
                        AppColors.tealPrimary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: AppColors.tealPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('vehicle_information'),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: FontSizes.subHeading,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedInput(_vehicleController, tr('vehicle_model'), Icons.directions_car_outlined),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _addVehicle,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (_vehicleModels.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                tr('your_vehicles'),
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              
              ..._vehicleModels.asMap().entries.map((entry) {
                final index = entry.key;
                final vehicle = entry.value;
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset((1 - value) * 200, 0),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.tealPrimary.withOpacity(0.1),
                                AppColors.tealPrimary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.tealPrimary.withOpacity(0.2),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.tealPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.directions_car,
                                color: AppColors.tealPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              vehicle,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () => _removeVehicle(vehicle),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // Enhanced App Settings Section
  Widget _buildEnhancedAppSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.greenPrimary.withOpacity(0.2),
                        AppColors.greenPrimary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: AppColors.greenPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('app_settings'),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: FontSizes.subHeading,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildEnhancedSwitchTile(
              tr('push_notifications_setting'),
              tr('receive_notifications_about_services'),
              Icons.notifications_outlined,
              true,
              (value) {},
            ),
            
            const SizedBox(height: 12),
            
            _buildEnhancedSwitchTile(
              tr('location_services'),
              tr('allow_app_to_access_location'),
              Icons.location_on_outlined,
              true,
              (value) {},
            ),
            
            const SizedBox(height: 16),
            
            _buildEnhancedLanguageTile(),
            
            const SizedBox(height: 12),
            
            _buildEnhancedNavTile(tr('privacy_policy'), Icons.privacy_tip_outlined, null),
            
            const SizedBox(height: 12),
            
            _buildEnhancedNavTile(tr('help_support'), Icons.help_outline, null),
            
            const SizedBox(height: 12),
            
            _buildEnhancedNavTile(tr('logout'), Icons.logout, _logout, isDestructive: true),
          ],
        ),
      ),
    );
  }

  // Enhanced Input Field
  Widget _buildEnhancedInput(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    int maxLines = 1, 
    bool isRequired = false
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clear label above the input
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              children: [
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: label == tr('full_name') ? tr('enter_your_full_name') : 
                        label == tr('phone_number') ? tr('enter_your_phone_number') : 
                        label == tr('vehicle_model') ? tr('enter_your_vehicle_model') :
                        'Enter your ${label.toLowerCase()}',
              hintStyle: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.red.shade400,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.red.shade400,
                  width: 2,
                ),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return '${tr("please_enter")} $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // Enhanced Date Selector
  Widget _buildEnhancedDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clear label above the date selector
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            tr('date_of_birth'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              _selectedDate != null
                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                  : tr('select_your_date_of_birth'),
              style: AppTextStyles.body.copyWith(
                color: _selectedDate != null ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.7),
                fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primary,
              size: 16,
            ),
            onTap: _selectDate,
          ),
        ),
      ],
    );
  }

  // Enhanced Switch Tile
  Widget _buildEnhancedSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Language Tile
  Widget _buildEnhancedLanguageTile() {
    final currentLang = context.locale.languageCode;
    final languageText = currentLang == 'en' ? tr('english') : tr('bangla');
    final flagEmoji = currentLang == 'en' ? '🇺🇸' : '🇧🇩';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.language,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          tr('language'),
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Text(flagEmoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              languageText,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: AppColors.primary,
          size: 16,
        ),
        onTap: _showLanguageDialog,
      ),
    );
  }

  // Enhanced Nav Tile
  Widget _buildEnhancedNavTile(
    String title, 
    IconData icon, 
    VoidCallback? onTap, {
    bool isDestructive = false
  }) {
    final color = isDestructive ? Colors.red : AppColors.primary;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : AppColors.textPrimary,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
