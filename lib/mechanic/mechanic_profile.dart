// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data'; // Add this for Uint8List
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

// Dummy contact info
final String phoneNumber = '+1 234 567 8901';
final String email = 'mechanic@example.com';
final String address = '123 Main Street, Springfield, USA';

// Editable contact info
String editablePhoneNumber = '+1 234 567 8901';
String editableEmail = 'mechanic@example.com';
String editableAddress = '123 Main Street, Springfield, USA';

// Dummy achievements
final List<Map<String, String>> achievements = [
  {
    'title': 'Trusted Badge',
    'desc': 'Completed 100 jobs',
    'date': '2025-06-01',
  },
  {
    'title': 'Speedy Service',
    'desc': 'Completed 10 jobs in a week',
    'date': '2025-05-20',
  },
  {
    'title': 'Customer Favorite',
    'desc': 'Received 50 five-star reviews',
    'date': '2025-04-15',
  },
  {
    'title': 'Early Bird',
    'desc': 'Started work before 7:00 AM for 30 days',
    'date': '2025-03-10',
  },
];

// Dummy reviews data
final List<Map<String, dynamic>> dummyReviews = [
  {
    'customerName': 'Alice Johnson',
    'rating': 5,
    'comment': 'Excellent service! Fixed my car quickly and professionally. Highly recommended!',
    'date': '2025-01-15',
    'jobType': 'Brake Repair',
  },
  {
    'customerName': 'Bob Smith',
    'rating': 4,
    'comment': 'Good work on my oil change. Arrived on time and explained everything clearly.',
    'date': '2025-01-10',
    'jobType': 'Oil Change',
  },
  {
    'customerName': 'Sarah Wilson',
    'rating': 5,
    'comment': 'Amazing mechanic! Diagnosed the problem immediately and fixed it at a fair price.',
    'date': '2025-01-08',
    'jobType': 'Engine Diagnostic',
  },
  {
    'customerName': 'Mike Davis',
    'rating': 4,
    'comment': 'Professional service. Fixed my transmission issue efficiently.',
    'date': '2025-01-05',
    'jobType': 'Transmission Repair',
  },
  {
    'customerName': 'Emma Brown',
    'rating': 5,
    'comment': 'Very knowledgeable and honest. Saved me money by suggesting a simple fix.',
    'date': '2025-01-03',
    'jobType': 'Battery Replacement',
  },
  {
    'customerName': 'David Lee',
    'rating': 3,
    'comment': 'Service was okay, but took longer than expected. Work quality was good though.',
    'date': '2024-12-28',
    'jobType': 'Tire Change',
  },
];

// Dummy notifications data
final List<Map<String, dynamic>> dummyNotifications = [
  {
    'id': '1',
    'title': 'New Job Request',
    'message': 'Alice Smith needs brake repair for Toyota Camry',
    'type': 'job',
    'time': '2 minutes ago',
    'isRead': false,
    'icon': Icons.build,
    'priority': 'high',
  },
  {
    'id': '2',
    'title': 'Payment Received',
    'message': 'You received ৳850 for Oil Change service',
    'type': 'payment',
    'time': '1 hour ago',
    'isRead': false,
    'icon': Icons.payment,
    'priority': 'medium',
  },
  {
    'id': '3',
    'title': 'App Update Available',
    'message': 'Version 2.1.0 is now available with new features',
    'type': 'update',
    'time': '3 hours ago',
    'isRead': true,
    'icon': Icons.system_update,
    'priority': 'low',
  },
  {
    'id': '4',
    'title': 'Special Offer',
    'message': 'Complete 5 jobs this week and get 10% bonus',
    'type': 'offer',
    'time': '1 day ago',
    'isRead': true,
    'icon': Icons.local_offer,
    'priority': 'medium',
  },
  {
    'id': '5',
    'title': 'Customer Review',
    'message': 'Bob Johnson left you a 5-star review',
    'type': 'review',
    'time': '2 days ago',
    'isRead': true,
    'icon': Icons.star,
    'priority': 'low',
  },
  {
    'id': '6',
    'title': 'Profile Verification',
    'message': 'Your mechanic certification has been verified',
    'type': 'verification',
    'time': '3 days ago',
    'isRead': true,
    'icon': Icons.verified_user,
    'priority': 'high',
  },
];

class MechanicProfile extends StatefulWidget {
  const MechanicProfile({super.key});

  @override
  State<MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<MechanicProfile> {
  bool isOnline = true;
  File? _profileImage;
  Uint8List? _webImage;
  double availableBalance = 1250;
  
  // Add these notification variables
  List<Map<String, dynamic>> notifications = List.from(dummyNotifications);
  bool hasUnreadNotifications = true;
  
  // Dummy data for earnings and jobs
  final List<double> weeklyEarnings = [120, 150, 90, 200, 170, 80, 130];
  final List<int> weeklyJobs = [2, 3, 1, 4, 3, 1, 2];
  final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String availableStart = '09:00 AM';
  String availableEnd = '06:00 PM';

  final List<String> timeOptions = [
    '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM'
  ];

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

  void _showWithdrawDialog() {
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'Bank';
    final List<String> methods = ['Bank', 'Bkash', 'Credit Card'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (৳)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    selectedMethod = val;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Withdraw Method',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amountText = amountController.text.trim();
                final amount = double.tryParse(amountText);

                if (amount == null || amount <= 0) {
                  _showBanner('Enter a valid amount.');
                  return;
                }

                if (amount > availableBalance) {
                  _showBanner('Insufficient balance.');
                  return;
                }

                Navigator.pop(context);
                _startOtpVerification(amount, selectedMethod);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    // Close the method
  }

  void _startOtpVerification(double amount, String method) {
    final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    final TextEditingController otpController = TextEditingController();

    // Simulate receiving OTP via banner
    _showBanner('Your OTP for withdrawing ৳${amount.toStringAsFixed(0)} is $otp');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter 6-digit OTP',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (otpController.text.trim() == otp) {
                  setState(() {
                    availableBalance -= amount;
                  });
                  Navigator.pop(context);
                  _showBanner('৳${amount.toStringAsFixed(0)} withdrawn successfully! New balance: ৳${availableBalance.toStringAsFixed(0)}');
                } else {
                  _showBanner('Incorrect OTP. Please try again.');
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
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

  void _showAvailabilityDialog() {
    String tempStart = availableStart;
    String tempEnd = availableEnd;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Available Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Start:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: tempStart,
                    items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() { tempStart = val; });
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('End:'),
                  const SizedBox(width: 24),
                  DropdownButton<String>(
                    value: tempEnd,
                    items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() { tempEnd = val; });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  availableStart = tempStart;
                  availableEnd = tempEnd;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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

  void _showReviewsDialog() {
  // Calculate average rating
  double averageRating = dummyReviews.fold(0.0, (sum, review) => sum + review['rating']) / dummyReviews.length;

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Reviews',
                      style: AppTextStyles.heading.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Summary Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < averageRating.floor() ? Icons.star : 
                              (index < averageRating ? Icons.star_half : Icons.star_border),
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${dummyReviews.length}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Total Reviews',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dummyReviews.length,
                  itemBuilder: (context, index) {
                    final review = dummyReviews[index];
                    return _buildReviewCard(review);
                  },
                ),
              ),
            ],
          ),
        ),
      ); // Added missing closing parenthesis for Dialog
    },
  );
} // <-- Add this closing parenthesis for the _showReviewsDialog method

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review['customerName'],
                  style: AppTextStyles.heading.copyWith(fontSize: 16),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review['rating'] ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Job type
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                review['jobType'],
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Review comment
            Text(
              review['comment'],
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            
            // Date
            Text(
              review['date'],
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ); // Fixed closing parenthesis
  }

  void _showTranslateDialog() {
    String selectedLanguage = 'English'; // Current language
    
    showDialog(
      context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Language Settings',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 20,
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
                  
                  // Current Language Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.language, size: 40, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          'Current Language',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Language Options
                  Text(
                    'Select Language',
                    style: AppTextStyles.heading.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  
                  // English Option
                  _buildLanguageOption(
                    'English',
                    '🇺🇸',
                    'Switch to English',
                    selectedLanguage == 'English',
                    () {
                      setState(() {
                        selectedLanguage = 'English';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Bangla Option
                  _buildLanguageOption(
                    'বাংলা (Bangla)',
                    '🇧🇩',
                    'বাংলায় পরিবর্তন করুন',
                    selectedLanguage == 'বাংলা (Bangla)',
                    () {
                      setState(() {
                        selectedLanguage = 'বাংলা (Bangla)';
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showBanner(
                            selectedLanguage == 'English' 
                              ? 'Language changed to English' 
                              : 'ভাষা বাংলায় পরিবর্তিত হয়েছে (Language changed to Bangla)'
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Apply Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ); 
        },
      );
    },
  );
}

  Widget _buildLanguageOption(String language, String flag, String description, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 16,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to logout?',
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'You will need to login again to access your account.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _performLogout();
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
                  Icon(Icons.logout, size: 18),
                  const SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() {
    // Show logout banner
    _showBanner('Logged out successfully');
    
    // Navigate to login page and clear all previous routes
    Future.delayed(Duration(milliseconds: 1500), () {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login', // Make sure this route exists in your main.dart
        (route) => false, // Remove all previous routes
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get current language dynamically
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          isEnglish ? 'Profile' : 'প্রোফাইল',
          style: AppTextStyles.heading.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: _showNotificationsDialog,
              ),
              // Unread notification badge
              if (hasUnreadNotifications)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notifications.where((n) => !n['isRead']).length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('Zobaer Ali', style: TextStyle(fontFamily: AppFonts.primaryFont)),
              accountEmail: Text('Certified Mechanic', style: TextStyle(fontFamily: AppFonts.secondaryFont)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: _getProfileImage(),
                child: _hasProfileImage() ? null : Icon(
                  Icons.person,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              decoration: BoxDecoration(color: AppColors.primary),
            ),
            _buildDrawerItem(Icons.star, isEnglish ? 'Reviews' : 'পর্যালোচনা'),
            _buildDrawerItem(Icons.logout, isEnglish ? 'Logout' : 'লগআউট'),
          ],
        ),
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

            // Achievements Section
            Text(
              isEnglish ? 'Achievements' : 'অর্জনসমূহ', 
              style: AppTextStyles.heading
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
                children: achievements.map((ach) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified, color: AppColors.accent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ach['title'] ?? '', style: AppTextStyles.heading.copyWith(fontSize: 16)),
                            Text(ach['desc'] ?? '', style: AppTextStyles.body),
                            Text('Achieved on: ${ach['date']}', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
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

            Text(
              isEnglish ? 'Earnings Summary' : 'আয়ের সারসংক্ষেপ', 
              style: AppTextStyles.heading
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Total Earnings Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEnglish ? 'Total Earnings (This Month)' : 'মোট আয় (এই মাস)', 
                        style: AppTextStyles.body
                      ),
                      Text('৳1,250',
                          style: TextStyle(
                            fontSize: FontSizes.subHeading,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppFonts.primaryFont,
                            color: AppColors.textPrimary,
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Available Balance Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, 
                                 color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isEnglish ? 'Available Balance' : 'উপলব্ধ ব্যালেন্স',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )
                            ),
                          ],
                        ),
                        Text('৳${availableBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: FontSizes.subHeading,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppFonts.primaryFont,
                              color: AppColors.primary,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ElevatedButton.icon(
                    onPressed: availableBalance > 0 ? _showWithdrawDialog : null,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: Text(
                      availableBalance > 0 
                        ? (isEnglish ? 'Withdraw Balance' : 'ব্যালেন্স উত্তোলন')
                        : (isEnglish ? 'No Balance Available' : 'কোন ব্যালেন্স নেই')
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: availableBalance > 0 ? AppColors.primary : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Earnings Analytics Section
            Text(
              isEnglish ? 'Earnings Analytics' : 'আয়ের বিশ্লেষণ', 
              style: AppTextStyles.heading
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
                  Text(
                    isEnglish ? 'Weekly Earnings' : 'সাপ্তাহিক আয়', 
                    style: AppTextStyles.body
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 12, bottom: 8),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (weeklyEarnings.reduce((a, b) => a > b ? a : b)) + 50,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      value % 50 == 0 ? value.toInt().toString() : '',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  return Text(idx >= 0 && idx < weekDays.length ? weekDays[idx] : '', style: TextStyle(fontSize: 12));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(weeklyEarnings.length, (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyEarnings[i],
                                color: AppColors.primary,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isEnglish ? 'Jobs Completed This Week' : 'এই সপ্তাহে সম্পন্ন কাজ', 
                    style: AppTextStyles.body
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(weeklyJobs.length, (i) => FlSpot(i.toDouble(), weeklyJobs[i].toDouble())),
                              isCurved: true,
                              color: AppColors.accent,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      value % 1 == 0 ? value.toInt().toString() : '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  return Transform.rotate(
                                    angle: -0.5,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        idx >= 0 && idx < weekDays.length ? weekDays[idx] : '',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          minY: 0,
                          maxY: (weeklyJobs.reduce((a, b) => a > b ? a : b)).toDouble() + 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              isEnglish ? 'Manage Availability' : 'উপলব্ধতা পরিচালনা', 
              style: AppTextStyles.heading
            ),
            const SizedBox(height: 12),
            Text(
              isEnglish 
                ? 'Available Hours: $availableStart - $availableEnd'
                : 'উপলব্ধ সময়: $availableStart - $availableEnd',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAvailabilityDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isEnglish ? 'Edit Availability' : 'উপলব্ধতা সম্পাদনা'
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(fontFamily: AppFonts.secondaryFont)),
      onTap: () {
        Navigator.pop(context); // Close drawer first
        if (title == (isEnglish ? 'Reviews' : 'পর্যালোচনা')) {
          _showReviewsDialog();
        } else if (title == (isEnglish ? 'Logout' : 'লগআউট')) {
          _showLogoutDialog();
        }
      },
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

  // Notification methods
  void _markNotificationAsRead(int index) {
    setState(() {
      notifications[index]['isRead'] = true;
      hasUnreadNotifications = notifications.any((n) => !n['isRead']);
    });
    
    _showBanner('Notification marked as read');
  }

  void _markAllNotificationsAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
      hasUnreadNotifications = false;
    });
    
    Navigator.pop(context);
    _showBanner('All notifications marked as read');
  }

  void _addNewNotification(String title, String message, String type, IconData icon, String priority) {
    setState(() {
      notifications.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'message': message,
        'type': type,
        'time': 'Just now',
        'isRead': false,
        'icon': icon,
        'priority': priority,
      });
      hasUnreadNotifications = true;
    });
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    Color priorityColor = notification['priority'] == 'high'
        ? Colors.red
        : notification['priority'] == 'medium'
            ? Colors.orange
            : Colors.green;

    Color typeColor = notification['type'] == 'job'
        ? AppColors.primary
        : notification['type'] == 'payment'
            ? Colors.green
            : notification['type'] == 'offer'
                ? Colors.purple
                : AppColors.textSecondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: notification['isRead'] ? 1 : 3,
      child: InkWell(
        onTap: () => _markNotificationAsRead(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: notification['isRead']
                ? Colors.white
                : AppColors.primary.withOpacity(0.05),
            border: Border.all(
              color: notification['isRead']
                  ? Colors.grey.shade200
                  : AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with priority indicator
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notification['icon'],
                      color: typeColor,
                      size: 24,
                    ),
                  ),
                  // Priority indicator
                  if (notification['priority'] == 'high')
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 16,
                              fontWeight: notification['isRead']
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification['isRead'])
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Text(
                      notification['message'],
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: notification['isRead']
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification['time'],
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification['type'].toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications',
                        style: AppTextStyles.heading.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      Row(
                        children: [
                          // Mark all as read button
                          TextButton(
                            onPressed: _markAllNotificationsAsRead,
                            child: Text(
                              'Mark All Read',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notification Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${notifications.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Total',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${notifications.where((n) => !n['isRead']).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            'Unread',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${notifications.where((n) => n['priority'] == 'high').length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Priority',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notifications List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}