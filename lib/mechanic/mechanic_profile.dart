// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:convert';
// Add this for Uint8List
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mechfind/mechanic/chat_screen.dart';
import 'package:mechfind/mechanic/upcoming_jobs_screen.dart';
import 'package:mechfind/mechanic/recent_activity_screen.dart';
import 'package:mechfind/mechanic/pending_jobs_screen.dart';

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

class _MechanicProfileState extends State<MechanicProfile> with TickerProviderStateMixin {
  bool isOnline = true;
  File? _profileImage;
  Uint8List? _webImage;
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> upcomingJobs = [];
  List<Map<String, dynamic>> pendingJobs = [];
  bool isLoadingActivities = true;
  bool isLoadingJobs = true;
  bool isLoadingPendingJobs = true;
  bool isLoadingProfile = true;
  bool isProcessingJob = false;
  final supabase = Supabase.instance.client;

  // Profile data
  String mechanicName = 'Loading...';
  String mechanicEmail = '';
  String mechanicPhone = '';
  String mechanicImageUrl = '';
  double mechanicRating = 0.0;
  int totalReviews = 0;
  double? mechanicLocationX;
  double? mechanicLocationY;
  String mechanicAddress = 'Loading address...';
  bool isLoadingAddress = true;

  // Location picker variables
  LatLng? _selectedMapLocation;
  bool _isPickingLocation = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchProfileData();
    _fetchRecentActivities();
    _fetchUpcomingJobs();
    _fetchPendingJobs();
  }
  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'engine repair':
        return Icons.build_circle_outlined;
      case 'tire service':
        return Icons.circle_outlined;
      case 'battery service':
        return Icons.battery_charging_full_outlined;
      case 'brake repair':
        return Icons.disc_full_outlined;
      case 'oil change':
        return Icons.oil_barrel_outlined;
      case 'transmission repair':
        return Icons.settings_outlined;
      case 'ac repair':
        return Icons.ac_unit_outlined;
      case 'electrical repair':
        return Icons.electrical_services_outlined;
      case 'towing':
        return Icons.local_shipping_outlined;
      case 'jumpstart':
        return Icons.flash_on_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('Error: User not logged in');
      setState(() {
        isLoadingProfile = false;
      });
      return;
    }

    setState(() {
      isLoadingProfile = true;
    });

    try {
      // Fetch user data from users table
      final userResponse = await supabase
          .from('users')
          .select('full_name, email, phone, image_url')
          .eq('id', user.id)
          .single();

      // Fetch mechanic rating and location from mechanics table
      final mechanicResponse = await supabase
          .from('mechanics')
          .select('rating, location_x, location_y')
          .eq('id', user.id)
          .single();

      // Use the mechanic rating if available, otherwise calculate from reviews
      double mechanicDbRating = (mechanicResponse['rating'] as num?)?.toDouble() ?? 0.0;
      double? locationX = (mechanicResponse['location_x'] as num?)?.toDouble();
      double? locationY = (mechanicResponse['location_y'] as num?)?.toDouble();

      // Fetch reviews count
      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', user.id);

      // Calculate rating and review count
      final reviews = reviewsResponse as List<dynamic>;
      double totalRating = 0.0;
      int reviewCount = reviews.length;
      
      if (reviewCount > 0) {
        for (var review in reviews) {
          totalRating += (review['rating'] as num).toDouble();
        }
        totalRating = totalRating / reviewCount;
      }

      setState(() {
        mechanicName = userResponse['full_name'] ?? 'Unknown';
        mechanicEmail = userResponse['email'] ?? '';
        mechanicPhone = userResponse['phone'] ?? '';
        mechanicImageUrl = userResponse['image_url'] ?? '';
        // Use database rating if available, otherwise use calculated rating
        mechanicRating = mechanicDbRating > 0 ? mechanicDbRating : totalRating;
        totalReviews = reviewCount;
        mechanicLocationX = locationX;
        mechanicLocationY = locationY;
        
        // Update editable contact info
        editablePhoneNumber = mechanicPhone;
        editableEmail = mechanicEmail;
        editableAddress = mechanicAddress;
        
        isLoadingProfile = false;
      });

      // Fetch address from coordinates
      if (locationX != null && locationY != null) {
        _fetchAddressFromCoordinates(locationX, locationY);
      } else {
        setState(() {
          mechanicAddress = 'Location not set';
          isLoadingAddress = false;
        });
      }

      print('✅ Profile data fetched successfully');
      print('Name: $mechanicName, Rating: $mechanicRating, Reviews: $totalReviews');

    } catch (e) {
      print('❌ Error fetching profile data: $e');
      setState(() {
        isLoadingProfile = false;
      });
      _showBanner('Failed to load profile data. Please try again.');
    }
  }

  Future<void> _updateProfile({
    String? newName,
    String? newEmail,
    String? newPhone,
    String? newImageUrl,
    double? newLocationX,
    double? newLocationY,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showBanner('User not logged in');
      return;
    }

    try {
      _showBanner('Updating profile...');

      // Prepare update data for users table
      Map<String, dynamic> userUpdateData = {};
      if (newName != null) userUpdateData['full_name'] = newName;
      if (newEmail != null) userUpdateData['email'] = newEmail;
      if (newPhone != null) userUpdateData['phone'] = newPhone;
      if (newImageUrl != null) userUpdateData['image_url'] = newImageUrl;

      // Prepare update data for mechanics table
      Map<String, dynamic> mechanicUpdateData = {};
      if (newLocationX != null) mechanicUpdateData['location_x'] = newLocationX;
      if (newLocationY != null) mechanicUpdateData['location_y'] = newLocationY;

      // Update users table if there's data to update
      if (userUpdateData.isNotEmpty) {
        await supabase
            .from('users')
            .update(userUpdateData)
            .eq('id', user.id);
      }

      // Update mechanics table if there's location data to update
      if (mechanicUpdateData.isNotEmpty) {
        await supabase
            .from('mechanics')
            .update(mechanicUpdateData)
            .eq('id', user.id);
      }

      // Update local state
      setState(() {
        if (newName != null) mechanicName = newName;
        if (newEmail != null) {
          mechanicEmail = newEmail;
          editableEmail = newEmail;
        }
        if (newPhone != null) {
          mechanicPhone = newPhone;
          editablePhoneNumber = newPhone;
        }
        if (newImageUrl != null) mechanicImageUrl = newImageUrl;
        if (newLocationX != null) mechanicLocationX = newLocationX;
        if (newLocationY != null) mechanicLocationY = newLocationY;
      });

      _showBanner('Profile updated successfully!');
      print('✅ Profile updated successfully');

    } catch (e) {
      print('❌ Error updating profile: $e');
      _showBanner('Failed to update profile. Please try again.');
    }
  }

  Future<void> _fetchAddressFromCoordinates(double lat, double lng) async {
    setState(() {
      isLoadingAddress = true;
    });

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ&types=place,locality,address&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Network timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          setState(() {
            mechanicAddress = features.first['place_name'] ?? 'Address not available';
            editableAddress = mechanicAddress;
            isLoadingAddress = false;
          });
        } else {
          setState(() {
            mechanicAddress = 'Address not available';
            editableAddress = mechanicAddress;
            isLoadingAddress = false;
          });
        }
      } else {
        setState(() {
          mechanicAddress = 'Address not available';
          editableAddress = mechanicAddress;
          isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching address from coordinates: $e');
      setState(() {
        mechanicAddress = 'Address not available';
        editableAddress = mechanicAddress;
        isLoadingAddress = false;
      });
    }
  }

  Future<void> _openLocationPicker() async {
    setState(() {
      _isPickingLocation = true;
    });

    try {
      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition();
      } catch (e) {
        print("Error getting current position for map: $e");
        // Use mechanic's current location or default to Dhaka
        currentPos = Position(
          latitude: mechanicLocationX ?? 23.8103,
          longitude: mechanicLocationY ?? 90.4125,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      final selectedLocation = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (context) => _MapLocationPicker(
            initialLocation: LatLng(currentPos!.latitude, currentPos.longitude),
          ),
        ),
      );

      if (selectedLocation != null) {
        setState(() {
          _selectedMapLocation = selectedLocation;
          mechanicLocationX = selectedLocation.latitude;
          mechanicLocationY = selectedLocation.longitude;
        });
        
        // Update address from new coordinates
        await _fetchAddressFromCoordinates(selectedLocation.latitude, selectedLocation.longitude);
      }
    } catch (e) {
      print('Error opening location picker: $e');
      _showBanner('Failed to open location picker');
    } finally {
      setState(() {
        _isPickingLocation = false;
      });
    }
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
            request_type,
            description,
            created_at,
            vehicle,
            status,
            user_id,
            guest_id,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'completed')
          .eq('request_type', 'emergency')
          .order('created_at', ascending: false)
          .limit(10);

      // Process response to add customer name
      final List<Map<String, dynamic>> processedActivities = [];
      for (var activity in response) {
        final Map<String, dynamic> processedActivity = Map<String, dynamic>.from(activity);
        
        // Extract customer info from users join
        if (activity['users'] != null) {
          processedActivity['customer_name'] = activity['users']['full_name'] ?? 'Unknown';
          processedActivity['customer_phone'] = activity['users']['phone'] ?? '';
          processedActivity['customer_image'] = activity['users']['image_url'] ?? '';
        } else {
          processedActivity['customer_name'] = 'Unknown Customer';
          processedActivity['customer_phone'] = '';
          processedActivity['customer_image'] = '';
        }
        
        processedActivities.add(processedActivity);
      }

      setState(() {
        recentActivities = processedActivities;
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

  Future<void> _fetchUpcomingJobs() async {
    try {
      setState(() {
        isLoadingJobs = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoadingJobs = false;
        });
        return;
      }

      final response = await supabase
          .from('requests')
          .select('''
            id,
            request_type,
            description,
            created_at,
            vehicle,
            status,
            user_id,
            guest_id,
            lat,
            lng,
            image,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'pending')
          .eq('request_type', 'normal')
          .order('created_at', ascending: false)
          .limit(10);

      // Process response to add customer name
      final List<Map<String, dynamic>> processedJobs = [];
      for (var job in response) {
        final Map<String, dynamic> processedJob = Map<String, dynamic>.from(job);
        
        // Extract customer info from users join
        if (job['users'] != null) {
          processedJob['customer_name'] = job['users']['full_name'] ?? 'Unknown';
          processedJob['customer_phone'] = job['users']['phone'] ?? '';
          processedJob['customer_image'] = job['users']['image_url'] ?? '';
        } else {
          processedJob['customer_name'] = 'Unknown Customer';
          processedJob['customer_phone'] = '';
          processedJob['customer_image'] = '';
        }
        
        processedJobs.add(processedJob);
      }

      setState(() {
        upcomingJobs = processedJobs;
        isLoadingJobs = false;
      });

    } catch (e) {
      print('Error fetching upcoming jobs: $e');
      setState(() {
        isLoadingJobs = false;
      });
      _showBanner('Failed to load upcoming jobs');
    }
  }

  Future<void> _fetchPendingJobs() async {
    try {
      setState(() {
        isLoadingPendingJobs = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoadingPendingJobs = false;
        });
        return;
      }

      final response = await supabase
          .from('requests')
          .select('''
            id,
            request_type,
            description,
            created_at,
            vehicle,
            status,
            user_id,
            guest_id,
            lat,
            lng,
            image,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'accepted')
          .eq('request_type', 'normal')
          .order('created_at', ascending: false)
          .limit(10);

      // Process response to add customer name
      final List<Map<String, dynamic>> processedJobs = [];
      for (var job in response) {
        final Map<String, dynamic> processedJob = Map<String, dynamic>.from(job);
        
        // Extract customer info from users join
        if (job['users'] != null) {
          processedJob['customer_name'] = job['users']['full_name'] ?? 'Unknown';
          processedJob['customer_phone'] = job['users']['phone'] ?? '';
          processedJob['customer_image'] = job['users']['image_url'] ?? '';
        } else {
          processedJob['customer_name'] = 'Unknown Customer';
          processedJob['customer_phone'] = '';
          processedJob['customer_image'] = '';
        }
        
        processedJobs.add(processedJob);
      }

      setState(() {
        pendingJobs = processedJobs;
        isLoadingPendingJobs = false;
      });

    } catch (e) {
      print('Error fetching pending jobs: $e');
      setState(() {
        isLoadingPendingJobs = false;
      });
      _showBanner('Failed to load pending jobs');
    }
  }

  Future<void> _acceptJob(String requestId) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Accept Job',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to accept this job request? You will be responsible for completing this service.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Accept Job',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isProcessingJob) return; // Prevent multiple requests

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner('Accepting job...');

      final user = supabase.auth.currentUser;
      if (user == null) {
        _showBanner('User not logged in');
        return;
      }

      // Update request status to accepted and confirm mechanic assignment
      await supabase
          .from('requests')
          .update({
            'status': 'accepted',
            'mechanic_id': user.id, // Ensure mechanic is properly assigned
          })
          .eq('id', requestId);

      _showBanner('Job accepted successfully!');
      
      // Refresh the upcoming jobs list
      await _fetchUpcomingJobs();
      
    } catch (e) {
      print('Error accepting job: $e');
      _showBanner('Failed to accept job');
    } finally {
      setState(() {
        isProcessingJob = false;
      });
    }
  }

  Future<void> _rejectJob(String requestId, {bool isFromPending = false}) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Job',
          style: AppTextStyles.heading.copyWith(
            color: Colors.red.shade600,
          ),
        ),
        content: Text(
          'Are you sure you want to reject this job request? This will make the request available for other mechanics.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Reject Job',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isProcessingJob) return; // Prevent multiple requests

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner('Rejecting job...');

      // Update request status to rejected and clear mechanic assignment
      await supabase
          .from('requests')
          .update({
            'status': 'rejected',
            'mechanic_id': null, // Clear mechanic assignment
            'mech_lat': null,    // Clear mechanic location
            'mech_lng': null,    // Clear mechanic location
          })
          .eq('id', requestId);

      _showBanner('Job rejected');
      
      // Refresh the appropriate list based on where the rejection came from
      if (isFromPending) {
        await _fetchPendingJobs();
      } else {
        await _fetchUpcomingJobs();
      }
      
    } catch (e) {
      print('Error rejecting job: $e');
      _showBanner('Failed to reject job');
    } finally {
      setState(() {
        isProcessingJob = false;
      });
    }
  }

  Future<void> _completeJob(String requestId) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Complete Job',
          style: AppTextStyles.heading.copyWith(
            color: Colors.green.shade600,
          ),
        ),
        content: Text(
          'Are you sure you want to mark this job as completed? This action cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Complete Job',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isProcessingJob) return; // Prevent multiple requests

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner('Completing job...');

      // Update request status to completed and set completion time
      await supabase
          .from('requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      _showBanner('Job completed successfully!');
      
      // Refresh both pending jobs and recent activities
      await _fetchPendingJobs();
      await _fetchRecentActivities();
      
    } catch (e) {
      print('Error completing job: $e');
      _showBanner('Failed to complete job');
    } finally {
      setState(() {
        isProcessingJob = false;
      });
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
                
                // Address Field with Location Picker
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _isPickingLocation ? null : () async {
                          Navigator.pop(context); // Close current dialog
                          await _openLocationPicker();
                          // Update address field with the new address
                          addressController.text = editableAddress;
                          // Reopen the dialog with updated address
                          _showEditContactsDialog();
                        },
                        icon: _isPickingLocation 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                        tooltip: isEnglish ? 'Pick from map' : 'মানচিত্র থেকে নির্বাচন করুন',
                      ),
                    ),
                  ],
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
                      onPressed: () async {
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
                        
                        Navigator.pop(context);
                        
                        // Update the profile in database
                        await _updateProfile(
                          newEmail: email,
                          newPhone: phone,
                          newLocationX: mechanicLocationX,
                          newLocationY: mechanicLocationY,
                        );
                        
                        // Update local address
                        setState(() {
                          editableAddress = address;
                        });
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
      backgroundColor: Colors.grey.shade50,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mechanicName != 'Loading...' ? mechanicName : 'Mechanic',
                    style: AppTextStyles.heading.copyWith(
                      color: Colors.white,
                      fontSize: FontSizes.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.work_outline, color: Colors.blue),
              title: Text(isEnglish ? 'Upcoming Jobs' : 'আসন্ন কাজ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UpcomingJobsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.pending_actions_outlined, color: Colors.orange),
              title: Text(isEnglish ? 'Pending Jobs' : 'চলমান কাজ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingJobsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.history_outlined, color: Colors.green),
              title: Text(isEnglish ? 'Recent Activity' : 'সাম্প্রতিক কার্যকলাপ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RecentActivityScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          isEnglish ? 'Profile' : 'প্রোফাইল',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              Colors.white,
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.08),
                ),
              ),
            ),
            // Main content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchProfileData();
                    await _fetchRecentActivities();
                  },
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header Card
                        _buildModernProfileCard(isEnglish),
                        const SizedBox(height: 24),
                        
                        // Contact Information Card
                        _buildModernContactCard(isEnglish),
                        const SizedBox(height: 24),
                        
                        // Upcoming Jobs Card
                        _buildModernUpcomingJobsCard(isEnglish),
                        const SizedBox(height: 24),
                        
                        // Recent Activity Card
                        _buildModernRecentActivityCard(isEnglish),
                        const SizedBox(height: 24),
                        
                        // Pending Jobs Card
                        _buildModernPendingJobsCard(isEnglish),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern UI Components
  Widget _buildModernProfileCard(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
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
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Profile Image with Pulse Animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: mechanicImageUrl.isNotEmpty 
                                  ? NetworkImage(mechanicImageUrl)
                                  : _getProfileImage(),
                              child: (mechanicImageUrl.isEmpty && !_hasProfileImage()) ? Icon(
                                Icons.person_rounded,
                                size: 48,
                                color: AppColors.primary,
                              ) : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.8),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            // Profile Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoadingProfile ? 'Loading...' : mechanicName,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: FontSizes.heading,
                      fontFamily: AppFonts.primaryFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isEnglish ? 'Certified Mechanic' : 'প্রত্যয়িত মেকানিক',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rating and Reviews
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              isLoadingProfile ? '0.0' : mechanicRating.toStringAsFixed(1),
                              style: AppTextStyles.label.copyWith(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isLoadingProfile 
                            ? (isEnglish ? 'Loading...' : 'লোড হচ্ছে...')
                            : isEnglish 
                                ? '$totalReviews Reviews' 
                                : '$totalReviews পর্যালোচনা',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
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
    );
  }

  Widget _buildModernContactCard(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.contact_page_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isEnglish ? 'Contact Information' : 'যোগাযোগের তথ্য',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: FontSizes.subHeading,
                      fontFamily: AppFonts.primaryFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showEditContactsDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildContactItem(
                  icon: Icons.phone_rounded,
                  title: isEnglish ? 'Phone' : 'ফোন',
                  value: isLoadingProfile ? 'Loading...' : editablePhoneNumber,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildContactItem(
                  icon: Icons.email_rounded,
                  title: isEnglish ? 'Email' : 'ইমেইল',
                  value: isLoadingProfile ? 'Loading...' : editableEmail,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildContactItem(
                  icon: Icons.location_on_rounded,
                  title: isEnglish ? 'Address' : 'ঠিকানা',
                  value: isLoadingAddress ? 'Loading address...' : editableAddress,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
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
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernUpcomingJobsCard(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isEnglish ? 'Upcoming Jobs' : 'আসন্ন কাজ',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: FontSizes.subHeading,
                      fontFamily: AppFonts.primaryFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (upcomingJobs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${upcomingJobs.length}',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoadingJobs 
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : upcomingJobs.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.work_off_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEnglish ? 'No pending jobs' : 'কোন অপেক্ষমান কাজ নেই',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: upcomingJobs.map((job) => _buildJobCard(job, isEnglish)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool isEnglish) {
    // Extract customer information similar to SOS card
    final userData = job['users'] ?? {};
    final userName = userData['full_name'] ?? 'Unknown Customer';
    final userImageUrl = userData['image_url'];
    final userPhone = userData['phone'] ?? 'N/A';
    
    // Location data
    final lat = double.tryParse(job['lat']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(job['lng']?.toString() ?? '') ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer header similar to SOS card
            _buildCustomerHeader(userName, userImageUrl, job),
            
            const SizedBox(height: 12),
            
            // Vehicle and description
            _buildJobDetails(job, isEnglish),
            
            const SizedBox(height: 16),
            
            // Location info
            if (lat != 0.0 && lng != 0.0)
              _buildLocationInfo(lat, lng, isEnglish),
            
            const SizedBox(height: 16),
            
            // Action buttons (Accept, Reject, Call/Chat)
            _buildJobActionButtons(job, userPhone, isEnglish),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerHeader(String userName, dynamic userImageUrl, Map<String, dynamic> job) {
    return Row(
      children: [
        // Customer avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 20,
              backgroundImage: (userImageUrl != null && 
                  userImageUrl.toString().isNotEmpty)
                  ? NetworkImage(userImageUrl.toString())
                  : const AssetImage('assets/quickfix.png') as ImageProvider,
              child: (userImageUrl == null || userImageUrl.toString().isEmpty)
                  ? Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Customer info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userName,
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body + 1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NORMAL',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: FontSizes.caption - 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Request time
              Text(
                _formatRequestTime(job['created_at']),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: FontSizes.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobDetails(Map<String, dynamic> job, bool isEnglish) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle info
          Row(
            children: [
              Icon(
                Icons.directions_car,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'Vehicle' : 'যানবাহন',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: FontSizes.caption + 1,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            job['vehicle']?.toString() ?? 'Not specified',
            style: AppTextStyles.body.copyWith(
              fontSize: FontSizes.body,
              color: AppColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'Description' : 'বর্ণনা',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: FontSizes.caption + 1,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            job['description']?.toString() ?? 'No description provided',
            style: AppTextStyles.body.copyWith(
              fontSize: FontSizes.body,
              color: AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(double lat, double lng, bool isEnglish) {
    return FutureBuilder<String>(
      future: _getAddressFromCoordinates(lat, lng),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 20,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnglish ? 'Customer Location' : 'গ্রাহকের অবস্থান',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: FontSizes.caption + 1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.hasData 
                          ? snapshot.data!
                          : snapshot.connectionState == ConnectionState.waiting
                              ? 'Loading location...'
                              : 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: FontSizes.body,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobActionButtons(Map<String, dynamic> job, String userPhone, bool isEnglish) {
    return Column(
      children: [
        // Accept and Reject buttons
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: isProcessingJob ? null : () => _rejectJob(job['id']),
                  icon: isProcessingJob 
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    isEnglish ? 'Reject' : 'প্রত্যাখ্যান',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: isProcessingJob ? null : () => _acceptJob(job['id']),
                  icon: isProcessingJob 
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    isEnglish ? 'Accept' : 'গ্রহণ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Call and Chat buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: userPhone != 'N/A' ? () => _makePhoneCall(userPhone) : null,
                icon: Icon(
                  Icons.phone,
                  size: 16,
                  color: userPhone != 'N/A' ? Colors.green : Colors.grey,
                ),
                label: Text(
                  isEnglish ? 'Call' : 'কল',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: userPhone != 'N/A' ? Colors.green : Colors.grey,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.05),
                  side: BorderSide(
                    color: userPhone != 'N/A' ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openChat(job),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: Colors.blue,
                ),
                label: Text(
                  isEnglish ? 'Chat' : 'চ্যাট',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.05),
                  side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRequestTime(String? createdAt) {
    if (createdAt == null) return 'Unknown time';
    
    try {
      final requestTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(requestTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ&types=place,locality,address&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Network timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          return features.first['place_name'] ?? 'Address not available';
        }
      }
      return 'Address not available';
    } catch (e) {
      return 'Address not available';
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    try {
      final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        print('Could not launch $uri');
        _showBanner('Unable to make call');
      }
    } catch (e) {
      print('Error making phone call: $e');
      _showBanner('Unable to make call');
    }
  }

  void _openChat(Map<String, dynamic> job) {
    // Get customer info
    final userData = job['users'] ?? {};
    final userName = userData['full_name'] ?? 'Unknown Customer';
    final userImageUrl = userData['image_url'] ?? '';
    final userId = job['user_id'] ?? job['guest_id'];
    
    if (userId == null) {
      _showBanner('Unable to start chat - user information not available');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: userId,
          receiverName: userName,
          receiverImageUrl: userImageUrl,
        ),
      ),
    );
  }

  Widget _buildModernRecentActivityCard(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.1),
                  Colors.blue.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.purple,
                        Colors.deepPurple,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isEnglish ? 'Recent Activity' : 'সাম্প্রতিক কার্যকলাপ',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: FontSizes.subHeading,
                    fontFamily: AppFonts.primaryFont,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoadingActivities 
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : recentActivities.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_rounded,
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
                    : Column(
                        children: recentActivities.map((activity) => _buildModernActivityCard(activity, isEnglish)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPendingJobsCard(bool isEnglish) {
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.deepOrange.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.orange,
                        Colors.deepOrange,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isEnglish ? 'Pending Jobs' : 'চলমান কাজ',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: FontSizes.subHeading,
                      fontFamily: AppFonts.primaryFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (pendingJobs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingJobs.length}',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoadingPendingJobs 
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : pendingJobs.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.pending_actions_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEnglish ? 'No pending jobs' : 'কোন চলমান কাজ নেই',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: pendingJobs.map((job) => _buildPendingJobCard(job, isEnglish)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingJobCard(Map<String, dynamic> job, bool isEnglish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.orange.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.deepOrange,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getServiceIcon(job['service_type'] ?? ''),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['service_type'] ?? 'Service',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${isEnglish ? 'Customer:' : 'গ্রাহক:'} ${job['customer_name'] ?? 'Unknown'}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: FontSizes.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEnglish ? 'Accepted' : 'গৃহীত',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Location
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job['location'] ?? 'Location not available',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.caption,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          if (job['description'] != null && job['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              job['description'],
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.caption,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPendingJobActionButton(
                onPressed: () => _makePhoneCall(job['customer_phone'] ?? ''),
                icon: Icons.phone,
                label: isEnglish ? 'Call' : 'কল',
                color: Colors.green,
              ),
              _buildPendingJobActionButton(
                onPressed: () => _openChat(job),
                icon: Icons.chat_bubble_outline,
                label: isEnglish ? 'Chat' : 'চ্যাট',
                color: Colors.blue,
              ),
              _buildPendingJobActionButton(
                onPressed: () => _rejectJob(job['id'], isFromPending: true),
                icon: Icons.close,
                label: isEnglish ? 'Reject' : 'প্রত্যাখ্যান',
                color: Colors.red,
              ),
              _buildPendingJobActionButton(
                onPressed: () => _completeJob(job['id']),
                icon: Icons.check_circle_outline,
                label: isEnglish ? 'Complete' : 'সম্পূর্ণ',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingJobActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: FontSizes.caption - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernActivityCard(Map<String, dynamic> activity, bool isEnglish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.05),
            Colors.purple.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['description'] ?? (isEnglish ? 'Service completed' : 'সেবা সম্পূর্ণ'),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.build_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity['request_type'] == 'emergency' 
                        ? (isEnglish ? 'Emergency Service' : 'জরুরি সেবা')
                        : (isEnglish ? 'Regular Service' : 'নিয়মিত সেবা'),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getTimeAgo(DateTime.parse(activity['created_at']), isEnglish),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (activity['vehicle'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity['vehicle'],
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
        ],
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

class _MapLocationPicker extends StatefulWidget {
  final LatLng initialLocation;

  const _MapLocationPicker({
    required this.initialLocation,
  });

  @override
  State<_MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<_MapLocationPicker> {
  LatLng? _selectedLocation;
  String _selectedAddress = "Loading...";

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateAddress(widget.initialLocation);
  }

  Future<void> _updateAddress(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (mounted) {
          setState(() {
            _selectedAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
                .replaceAll(RegExp(r'^,\s*'), '') // Remove leading comma
                .replaceAll(RegExp(r',\s*$'), ''); // Remove trailing comma
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Pick Location',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.gradientStart,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selectedLocation != null 
              ? () => Navigator.pop(context, _selectedLocation)
              : null,
            child: Text(
              'Confirm',
              style: AppTextStyles.body.copyWith(
                color: _selectedLocation != null ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Address display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Location:',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  if (mounted) {
                    setState(() {
                      _selectedLocation = point;
                    });
                  }
                  _updateAddress(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ",
                  additionalOptions: {
                    'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ',
                    'id': 'mapbox.mapbox-traffic-v1',
                  },
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.6),
                                spreadRadius: 4,
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.background,
            child: Text(
              'Tap on the map to select your location',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}