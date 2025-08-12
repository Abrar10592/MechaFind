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

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
            const SnackBar(content: Text('Unable to load profile data')),
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
          SnackBar(content: Text('Error loading profile: $e')),
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
      appBar: AppBar(
        title: Text('Profile & Settings', style: TextStyle(fontSize: 22,color: AppColors.textlight)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading && _nameController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Picture
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _profileImage != null 
                                  ? FileImage(_profileImage!) 
                                  : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null),
                              child: _profileImage == null && _profileImageUrl == null 
                                  ? const Icon(Icons.person, size: 60) 
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary,
                                child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to change profile picture',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Personal Info
              _buildSectionCard(
                title: 'Personal Information',
                children: [
                  _buildInput(_nameController, 'Full Name', Icons.person),
                  _buildInput(_phoneController, 'Phone Number', Icons.phone),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _selectedDate != null
                          ? 'Date of Birth: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date of Birth',
                      style: AppTextStyles.body,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _selectDate,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle Info
              _buildSectionCard(
                title: 'Vehicle Information',
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildInput(_vehicleController, 'Vehicle Model', Icons.directions_car)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addVehicle,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_vehicleModels.isNotEmpty)
                    ...[
                      Text('Your Vehicles:', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      ..._vehicleModels.map(
                        (vehicle) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.directions_car),
                            title: Text(vehicle, style: AppTextStyles.body),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeVehicle(vehicle),
                            ),
                          ),
                        ),
                      ),
                    ]
                ],
              ),

              const SizedBox(height: 16),

              // App Settings
              _buildSectionCard(
                title: 'App Settings',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Push Notifications', style: AppTextStyles.body),
                    subtitle: Text('Receive notifications about services', style: AppTextStyles.label),
                    value: true,
                    onChanged: (value) {},
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Location Services', style: AppTextStyles.body),
                    subtitle: Text('Allow app to access your location', style: AppTextStyles.label),
                    value: true,
                    onChanged: (value) {},
                  ),
                  _buildLanguageTile(),
                  _buildNavTile('Privacy Policy', Icons.privacy_tip),
                  _buildNavTile('Help & Support', Icons.help),
                  _buildNavTile('Logout', Icons.logout, onTap: _logout),
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
              // Navigate to messages
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

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
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
            const SnackBar(
              content: Text('Failed to save vehicle. Changes will be saved when you save your profile.'),
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
          const SnackBar(
            content: Text('Failed to remove vehicle. Changes will be saved when you save your profile.'),
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

        // Prepare update data
        Map<String, dynamic> updateData = {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };

        // Note: Email is not updated as it's managed by auth system

        // Add date of birth if selected
        if (_selectedDate != null) {
          updateData['dob'] = _selectedDate!.toIso8601String().split('T')[0]; // Date only
        } else {
          // If no date selected, set to null
          updateData['dob'] = null;
        }

        // Handle vehicle models array
        // First, check if there's a vehicle in the input box that hasn't been added yet
        String pendingVehicle = _vehicleController.text.trim();
        if (pendingVehicle.isNotEmpty && !_vehicleModels.contains(pendingVehicle)) {
          _vehicleModels.add(pendingVehicle);
          _vehicleController.clear(); // Clear the input after adding
        }
        
        updateData['veh_model'] = _vehicleModels;

        // Add image URL if uploaded
        if (imageUrl != null) {
          updateData['image_url'] = imageUrl;
        }

        // Update user data in database using UserService
        final success = await UserService.updateUserProfile(updateData);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update profile. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving profile: $e'),
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

  Widget _buildLanguageTile() {
    final currentLang = context.locale.languageCode;
    final languageText = currentLang == 'en' ? 'English' : 'বাংলা';
    final flagEmoji = currentLang == 'en' ? '🇺🇸' : '🇧🇩';
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.language, color: AppColors.primary),
      title: Text('Language / ভাষা', style: AppTextStyles.body),
      subtitle: Row(
        children: [
          Text(flagEmoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text(languageText, style: AppTextStyles.label),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: _showLanguageDialog,
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Language / ভাষা নির্বাচন করুন', style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Row(
                children: [
                  Text('🇺🇸', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 12),
                  Text('English', style: AppTextStyles.body),
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
                  Text('বাংলা', style: AppTextStyles.body),
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
            child: Text('Cancel / বাতিল'),
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
            ? 'Language changed to English' 
            : 'ভাষা বাংলায় পরিবর্তিত হয়েছে'
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
        title: Text('Logout', style: AppTextStyles.heading),
        content: Text('Are you sure you want to logout?', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
