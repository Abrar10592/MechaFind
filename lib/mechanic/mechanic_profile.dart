// ignore_for_file: deprecated_member_use

import 'dart:io';
// Add this for Uint8List
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Dummy contact info
final String phoneNumber = '+1 234 567 8901';
final String email = 'mechanic@example.com';
final String address = '123 Main Street, Springfield, USA';

// Editable contact info
String editablePhoneNumber = '+1 234 567 8901';
String editableEmail = 'mechanic@example.com';
String editableAddress = '123 Main Street, Springfield, USA';

class MechanicProfile extends StatefulWidget {
  const MechanicProfile({super.key});

  @override
  State<MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<MechanicProfile> {
  bool isOnline = true;
  File? _profileImage;
  Uint8List? _webImage;
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoadingActivities = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchRecentActivities();
  }

  Future<void> _fetchRecentActivities() async {
    try {
      setState(() {
        isLoadingActivities = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoadingActivities = false;
        });
        return;
      }

      final response = await supabase
          .from('requests')
          .select('''
            id,
            service_type,
            description,
            created_at,
            completed_at,
            customer_name,
            customer_phone,
            location_address,
            vehicle
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(5);

      setState(() {
        recentActivities = List<Map<String, dynamic>>.from(response);
        isLoadingActivities = false;
      });

    } catch (e) {
      print('Error fetching recent activities: $e');
      setState(() {
        isLoadingActivities = false;
      });
      _showBanner('Failed to load recent activities');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      
      // Show processing immediately
      _showBanner('Selecting image...');
      
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _showBanner('Processing image...');
        
        // Small delay for visual feedback
        await Future.delayed(Duration(milliseconds: 300));
        
        if (kIsWeb) {
          // For web platform
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _profileImage = null; // Clear mobile image
          });
        } else {
          // For mobile platform
          setState(() {
            _profileImage = File(pickedFile.path);
            _webImage = null; // Clear web image
          });
        }
        
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _showBanner('Profile picture updated successfully!');
      } else {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      _showBanner('Image selection failed. Please try again.');
      print('Image picker error: $e');
    }
  }

  void _showBanner(String message) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: AppColors.primary.withOpacity(0.95),
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditContactsDialog() {
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    final TextEditingController phoneController = TextEditingController(text: editablePhoneNumber);
    final TextEditingController emailController = TextEditingController(text: editableEmail);
    final TextEditingController addressController = TextEditingController(text: editableAddress);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEnglish ? 'Edit Contact Information' : 'যোগাযোগের তথ্য সম্পাদনা',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Phone Number Field
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Phone Number' : 'ফোন নম্বর',
                    prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Email Field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Email Address' : 'ইমেইল ঠিকানা',
                    prefixIcon: Icon(Icons.email, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Address Field
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Address' : 'ঠিকানা',
                    prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isEnglish ? 'Cancel' : 'বাতিল',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Validate inputs
                        final phone = phoneController.text.trim();
                        final email = emailController.text.trim();
                        final address = addressController.text.trim();
                        
                        if (phone.isEmpty || email.isEmpty || address.isEmpty) {
                          _showBanner(isEnglish ? 'Please fill in all fields' : 'সব ক্ষেত্র পূরণ করুন');
                          return;
                        }
                        
                        // Basic email validation
                        if (!email.contains('@') || !email.contains('.')) {
                          _showBanner(isEnglish ? 'Please enter a valid email address' : 'একটি বৈধ ইমেইল ঠিকানা লিখুন');
                          return;
                        }
                        
                        // Update the contact information
                        setState(() {
                          editablePhoneNumber = phone;
                          editableEmail = email;
                          editableAddress = address;
                        });
                        
                        Navigator.pop(context);
                        _showBanner(isEnglish ? 'Contact information updated successfully!' : 'যোগাযোগের তথ্য সফলভাবে আপডেট হয়েছে!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save, size: 18),
                          const SizedBox(width: 8),
                          Text(isEnglish ? 'Save Changes' : 'পরিবর্তন সংরক্ষণ'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current language dynamically
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    return Scaffold(
      appBar: AppBar(
        leading: null, // Remove hamburger menu
        automaticallyImplyLeading: false, // Prevent default back button
        title: Text(
          isEnglish ? 'Profile' : 'প্রোফাইল',
          style: AppTextStyles.heading.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: _getProfileImage(),
                            child: _hasProfileImage() ? null : Icon(
                              Icons.person,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          // Camera icon overlay
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zobaer Ali', style: AppTextStyles.heading),
                        Text('Certified Mechanic', style: AppTextStyles.label),
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: isOnline,
                      onChanged: (val) => setState(() => isOnline = val),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Contacts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEnglish ? 'Contacts' : 'যোগাযোগ', 
                  style: AppTextStyles.heading
                ),
                IconButton(
                  onPressed: _showEditContactsDialog,
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  tooltip: isEnglish ? 'Edit Contacts' : 'যোগাযোগ সম্পাদনা',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(editablePhoneNumber, style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(editableEmail, style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(editableAddress, style: AppTextStyles.body)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              isEnglish ? 'Upcoming Jobs' : 'আসন্ন কাজ', 
              style: AppTextStyles.heading
            ),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildJobCard('Alice Smith', 'Toyota Camry 2019', 'Brake Repair', 'Today 3:00 PM'),
                _buildJobCard('Bob Johnson', 'Honda Accord 2018', 'Oil Change', 'Today 5:00 PM'),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Activity Section
            Text(
              isEnglish ? 'Recent Activity' : 'সাম্প্রতিক কার্যকলাপ', 
              style: AppTextStyles.heading
            ),
            const SizedBox(height: 12),
            isLoadingActivities 
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : recentActivities.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEnglish ? 'No completed requests yet' : 'এখনও কোন সম্পূর্ণ অনুরোধ নেই',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: recentActivities.map((activity) => _buildActivityCard(activity, isEnglish)).toList(),
                      ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(String clientName, String carModel, String jobType, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName, style: AppTextStyles.heading.copyWith(fontSize: 18)),
            Text(carModel, style: AppTextStyles.label),
            const SizedBox(height: 4),
            Text('Job: $jobType', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time, style: AppTextStyles.label),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Accept'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, bool isEnglish) {
    final completedAt = DateTime.tryParse(activity['completed_at'] ?? '');
    final timeAgo = completedAt != null ? _getTimeAgo(completedAt, isEnglish) : '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['customer_name'] ?? (isEnglish ? 'Unknown Customer' : 'অজানা গ্রাহক'),
                        style: AppTextStyles.heading.copyWith(fontSize: 16),
                      ),
                      Text(
                        activity['vehicle'] ?? (isEnglish ? 'Vehicle not specified' : 'গাড়ি নির্দিষ্ট নয়'),
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activity['service_type'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activity['service_type'],
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (activity['description'] != null && activity['description'].toString().isNotEmpty)
              Text(
                activity['description'],
                style: AppTextStyles.body.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (activity['location_address'] != null && activity['location_address'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity['location_address'],
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime, bool isEnglish) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return isEnglish 
          ? '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago'
          : '${difference.inDays} দিন আগে';
    } else if (difference.inHours > 0) {
      return isEnglish 
          ? '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago'
          : '${difference.inHours} ঘন্টা আগে';
    } else if (difference.inMinutes > 0) {
      return isEnglish 
          ? '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago'
          : '${difference.inMinutes} মিনিট আগে';
    } else {
      return isEnglish ? 'Just now' : 'এইমাত্র';
    }
  }

  // Helper methods
  ImageProvider? _getProfileImage() {
    if (kIsWeb && _webImage != null) {
      return MemoryImage(_webImage!);
    } else if (!kIsWeb && _profileImage != null) {
      return FileImage(_profileImage!);
    }
    return null;
  }

  bool _hasProfileImage() {
    return (kIsWeb && _webImage != null) || (!kIsWeb && _profileImage != null);
  }
}