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
  
  // Real-time subscription
  RealtimeChannel? _reviewsChannel;

  // Profile data
  String mechanicName = 'Loading...';
  String mechanicEmail = '';
  String mechanicPhone = '';
  String mechanicImageUrl = '';
  double mechanicRating = 5.0;
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
    _setupRealtimeSubscription();
  }

  // Setup real-time subscription for reviews
  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      // Subscribe to reviews table changes for this mechanic
      _reviewsChannel = supabase
          .channel('reviews_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reviews',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'mechanic_id',
              value: user.id,
            ),
            callback: (payload) {
              print('Real-time review update received: ${payload.eventType}');
              // Refresh profile data when reviews change
              _fetchProfileData();
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    
    // Properly dispose of real-time subscription
    try {
      if (_reviewsChannel != null) {
        _reviewsChannel!.unsubscribe();
        _reviewsChannel = null;
      }
    } catch (e) {
      print('Error cleaning up real-time subscription: $e');
    }
    
    super.dispose();
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

      print('Mechanic data retrieved: ${mechanicResponse}'); // Debug log
      print('Mechanic ID being used: ${user.id}'); // Debug log

      // Use the mechanic rating if available, otherwise calculate from reviews
      // Handle null vs 0.0 properly - null means no rating set, 0.0 is a valid rating
      num? rawRating = mechanicResponse['rating'] as num?;
      double? mechanicDbRating = rawRating?.toDouble();
      double? locationX = (mechanicResponse['location_x'] as num?)?.toDouble();
      double? locationY = (mechanicResponse['location_y'] as num?)?.toDouble();

      // First, let's check if there are ANY reviews in the reviews table
      final allReviewsResponse = await supabase
          .from('reviews')
          .select('id, mechanic_id')
          .limit(10);
      
      print('Total reviews in database: ${allReviewsResponse.length}'); // Debug log
      if (allReviewsResponse.isNotEmpty) {
        print('Sample review mechanic_ids: ${allReviewsResponse.map((r) => r['mechanic_id']).take(3).toList()}'); // Debug log
      }

      // Fetch reviews count with better debugging
      print('Fetching reviews count for mechanic: ${user.id}'); // Debug log
      
      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating, created_at')
          .eq('mechanic_id', user.id)
          .order('created_at', ascending: false);

      print('Reviews response: ${reviewsResponse.length} reviews found'); // Debug log

      // Calculate rating and review count
      final reviews = reviewsResponse as List<dynamic>;
      double totalRating = 5.0; // Default to 5.0 when no reviews
      int reviewCount = reviews.length;
      
      if (reviewCount > 0) {
        totalRating = 0.0; // Reset to calculate from reviews
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
        // Use calculated rating from reviews if available, otherwise use database rating
        // If both are 0 or unavailable, default to 5.0
        if (reviewCount > 0) {
          mechanicRating = totalRating; // Use calculated rating when reviews exist
        } else if (mechanicDbRating != null && mechanicDbRating > 0) {
          mechanicRating = mechanicDbRating; // Use database rating if it's set and > 0
        } else {
          mechanicRating = 5.0; // Default to 5.0 when no reviews and no valid database rating
        }
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
        mechanicName = 'Failed to load';
        mechanicEmail = '';
        mechanicPhone = '';
        mechanicImageUrl = '';
        mechanicRating = 5.0;
        totalReviews = 0;
        mechanicAddress = 'Address unavailable';
        isLoadingAddress = false;
      });
      
      // Show user-friendly error message based on error type
      String errorMessage = 'Failed to load profile data. Please try again.';
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('auth')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      }
      
      _showBanner(errorMessage);
    }
  }

  // Show reviews screen with individual reviews
  void _showReviewsScreen() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReviewsDialog(
          mechanicId: supabase.auth.currentUser?.id ?? '',
          mechanicName: mechanicName,
          mechanicRating: mechanicRating,
          totalReviews: totalReviews,
        );
      },
    );
    
    // Refresh profile data when returning from reviews screen
    // This ensures the review count is always up-to-date
    _fetchProfileData();
  }

  // Test method to verify database connectivity and data
  Future<void> _testDatabaseConnection() async {
    try {
      print('=== DATABASE CONNECTIVITY TEST ===');
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }
      
      print('✅ User logged in: ${user.id}');
      
      // Test 1: Check if mechanic exists in mechanics table
      try {
        final mechanicCheck = await supabase
            .from('mechanics')
            .select('id')
            .eq('id', user.id);
        print('✅ Mechanic exists in mechanics table: ${mechanicCheck.isNotEmpty}');
        if (mechanicCheck.isEmpty) {
          print('❌ Current user is not in mechanics table!');
        }
      } catch (e) {
        print('❌ Error checking mechanics table: $e');
      }
      
      // Test 2: Check total reviews in database
      try {
        final allReviews = await supabase
            .from('reviews')
            .select('id, mechanic_id, user_id, rating');
        print('✅ Total reviews in database: ${allReviews.length}');
        if (allReviews.isNotEmpty) {
          final uniqueMechanics = allReviews.map((r) => r['mechanic_id']).toSet();
          print('✅ Reviews for ${uniqueMechanics.length} different mechanics');
          print('✅ Sample mechanic IDs with reviews: ${uniqueMechanics.take(3).toList()}');
        }
      } catch (e) {
        print('❌ Error fetching all reviews: $e');
      }
      
      // Test 3: Check reviews for current user
      try {
        final myReviews = await supabase
            .from('reviews')
            .select('*')
            .eq('mechanic_id', user.id);
        print('✅ Reviews for current mechanic (${user.id}): ${myReviews.length}');
        if (myReviews.isNotEmpty) {
          print('✅ Sample review: ${myReviews[0]}');
        }
      } catch (e) {
        print('❌ Error fetching my reviews: $e');
      }
      
      print('=== END DATABASE TEST ===');
    } catch (e) {
      print('❌ Database test failed: $e');
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
      if (newImageUrl != null) mechanicUpdateData['image_url'] = newImageUrl; // Add image to mechanics table too

      // Update users table if there's data to update
      if (userUpdateData.isNotEmpty) {
        print('🔄 Updating users table with: $userUpdateData');
        await supabase
            .from('users')
            .update(userUpdateData)
            .eq('id', user.id);
        print('✅ Users table updated successfully');
      }

      // Update mechanics table if there's data to update
      if (mechanicUpdateData.isNotEmpty) {
        print('🔄 Updating mechanics table with: $mechanicUpdateData');
        await supabase
            .from('mechanics')
            .update(mechanicUpdateData)
            .eq('id', user.id);
        print('✅ Mechanics table updated successfully');
      }

      // Update local state
      if (mounted) {
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
          if (newImageUrl != null) {
            mechanicImageUrl = newImageUrl;
            // Only clear local images if we successfully saved to database
            print('✅ Database image URL updated, clearing local cache');
          }
          if (newLocationX != null) mechanicLocationX = newLocationX;
          if (newLocationY != null) mechanicLocationY = newLocationY;
        });
      }

      _showBanner('Profile updated successfully!', autoHide: true);
      print('✅ Profile updated successfully');

    } catch (e) {
      print('❌ Error updating profile: $e');
      _showBanner('Failed to update profile. Please try again.');
    }
  }

  // Method to refresh profile data (useful after image updates)
  Future<void> _refreshProfileData() async {
    print('🔄 Refreshing profile data...');
    await _fetchProfileData();
    if (mounted) {
      setState(() {
        // Force UI rebuild
      });
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
        print('DEBUG: No authenticated user found');
        setState(() {
          isLoadingActivities = false;
        });
        return;
      }

      print('DEBUG: Fetching recent activities for mechanic_id: ${user.id}');

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
            mechanic_id,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(20);

      print('DEBUG: Recent activities query response: ${response.length} records found');
      
      // Debug: Print all completed tasks for this mechanic
      for (var i = 0; i < response.length; i++) {
        final activity = response[i];
        print('DEBUG Activity $i: ID=${activity['id']}, Type=${activity['request_type']}, Status=${activity['status']}, Created=${activity['created_at']}, Description=${activity['description']}');
      }

      // Also fetch ALL completed tasks to check if the missing one exists
      final allCompletedResponse = await supabase
          .from('requests')
          .select('''
            id,
            request_type,
            description,
            created_at,
            status,
            mechanic_id,
            users(full_name, phone, image_url)
          ''')
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      print('DEBUG: Total completed tasks in system: ${allCompletedResponse.length}');
      print('DEBUG: Tasks assigned to this mechanic (${user.id}):');
      
      var mechanicTaskCount = 0;
      for (var task in allCompletedResponse) {
        if (task['mechanic_id'] == user.id) {
          mechanicTaskCount++;
          print('DEBUG Mechanic Task: ID=${task['id']}, Created=${task['created_at']}, Type=${task['request_type']}');
        }
      }
      print('DEBUG: Total completed tasks for this mechanic: $mechanicTaskCount');

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

      // Debug: Cross-reference with reviews to find missing completed tasks
      try {
        final reviewsResponse = await supabase
            .from('reviews')
            .select('id, mechanic_id, request_id, rating, comment, created_at')
            .eq('mechanic_id', user.id);
        
        print('DEBUG: Found ${reviewsResponse.length} reviews for this mechanic');
        
        final requestIdsFromReviews = reviewsResponse.map((review) => review['request_id']).toSet();
        final requestIdsFromActivities = response.map((activity) => activity['id']).toSet();
        
        print('DEBUG: Request IDs from reviews: $requestIdsFromReviews');
        print('DEBUG: Request IDs from recent activities: $requestIdsFromActivities');
        
        final missingRequestIds = requestIdsFromReviews.difference(requestIdsFromActivities);
        if (missingRequestIds.isNotEmpty) {
          print('DEBUG: FOUND MISSING TASKS! Request IDs with reviews but not in recent activities: $missingRequestIds');
          
          // Fetch details of missing tasks
          for (var requestId in missingRequestIds) {
            final missingTaskResponse = await supabase
                .from('requests')
                .select('id, status, mechanic_id, created_at, request_type, description')
                .eq('id', requestId);
            
            if (missingTaskResponse.isNotEmpty) {
              final task = missingTaskResponse.first;
              print('DEBUG: Missing task details: ID=${task['id']}, Status=${task['status']}, MechanicID=${task['mechanic_id']}, Created=${task['created_at']}');
            }
          }
        } else {
          print('DEBUG: All reviewed tasks are showing in recent activities');
        }
      } catch (reviewsError) {
        print('DEBUG: Error checking reviews cross-reference: $reviewsError');
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

      _showBanner('Job accepted successfully!', autoHide: true);
      
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
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    // Show rejection dialog with reason selection
    final result = await _showRejectJobDialog(isEnglish);

    if (result == null || result['confirmed'] != true) return;

    if (isProcessingJob) return; // Prevent multiple requests

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner(isEnglish ? 'Rejecting job...' : 'চাকরি প্রত্যাখ্যান করা হচ্ছে...');

      // Get current user ID
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showBanner(isEnglish ? 'User not logged in' : 'ব্যবহারকারী লগ ইন করেননি');
        return;
      }

      // Update request status to canceled (rejected) and clear mechanic assignment
      print('🔄 Updating request $requestId to canceled status...');
      print('📋 Update data: {status: canceled, mechanic_id: null, reason: ${result['reason']}}');
      
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('❌ No authenticated user found');
        return;
      }

      try {
        // Simple approach: Just change status to canceled 
        // This should work with existing RLS policies
        print('🔄 Attempting to update request $requestId to canceled status');
        print('👤 Current user ID: $currentUserId');
        
        final updateResponse = await supabase
            .from('requests')
            .update({'status': 'canceled'})
            .eq('id', requestId)
            .eq('mechanic_id', currentUserId) // Only update if assigned to current user
            .select(); // Add select to see what was updated
            
        print('✅ Request status updated to canceled');
        print('📋 Update response: $updateResponse');
        
        // If the update response is empty, it means no rows were affected
        if (updateResponse.isEmpty) {
          print('⚠️ No rows were updated - request may not exist or not assigned to current user');
          
          // Let's verify the request exists and check its current assignment
          final checkResponse = await supabase
              .from('requests')
              .select('id, status, mechanic_id')
              .eq('id', requestId)
              .maybeSingle();
              
          print('🔍 Request check: $checkResponse');
        }
        
        // Separately add to ignored requests (if this table allows inserts)
        try {
          await supabase.from('ignored_requests').insert({
            'mechanic_id': currentUserId,
            'request_id': requestId,
            'reason': result['reason'],
          });
          print('✅ Added to ignored requests');
        } catch (ignoreError) {
          print('⚠️ Could not add to ignored requests: $ignoreError');
          // This is not critical, continue
        }
      } catch (updateError) {
        print('❌ Database update failed: $updateError');
        throw updateError; // Re-throw to be caught by outer catch block
      }
      
      // Small delay to ensure database update has propagated
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify the update was successful
      try {
        final verifyResponse = await supabase
            .from('requests')
            .select('id, status, mechanic_id, rejection_reason')
            .eq('id', requestId)
            .single();
        print('🔍 Verification query result: $verifyResponse');
        
        if (verifyResponse['status'] != 'canceled') {
          print('⚠️ WARNING: Status was not updated to canceled!');
        }
        if (verifyResponse['mechanic_id'] != null) {
          print('⚠️ WARNING: Mechanic ID was not cleared!');
        }
      } catch (verifyError) {
        print('❌ Verification query failed: $verifyError');
      }

      // Add to ignored requests so this request won't appear again for this mechanic
      try {
        await supabase
            .from('ignored_requests')
            .insert({
              'mechanic_id': user.id,
              'request_id': requestId,
            });
        print('✅ Request added to ignored list for mechanic');
      } catch (e) {
        // Ignore if already exists (duplicate key constraint)
        print('⚠️ Request might already be in ignored list: $e');
      }

      _showBanner(
        isEnglish 
          ? 'Job rejected successfully!' 
          : 'চাকরি সফলভাবে প্রত্যাখ্যান করা হয়েছে!', 
        autoHide: true
      );
      
      // Force refresh both job lists to ensure UI is updated
      print('🔄 Refreshing job lists after rejection...');
      if (isFromPending) {
        await _fetchPendingJobs();
        print('✅ Pending jobs refreshed');
      } else {
        await _fetchUpcomingJobs();
        print('✅ Upcoming jobs refreshed');
      }
      
      // Also refresh the other list in case the request appeared in both
      if (isFromPending) {
        await _fetchUpcomingJobs();
        print('✅ Also refreshed upcoming jobs');
      } else {
        await _fetchPendingJobs();
        print('✅ Also refreshed pending jobs');
      }
      
    } catch (e) {
      print('❌ Error rejecting job: $e');
      _showBanner(
        isEnglish 
          ? 'Failed to reject job. Please try again.' 
          : 'চাকরি প্রত্যাখ্যান করতে ব্যর্থ। আবার চেষ্টা করুন।'
      );
    } finally {
      setState(() {
        isProcessingJob = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _showRejectJobDialog(bool isEnglish) async {
    String? selectedReason;
    final TextEditingController customReasonController = TextEditingController();

    final List<String> reasonsEnglish = [
      'Too far from my location',
      'Already have too many jobs',
      'Not available at this time',
      'Service not in my expertise',
      'Customer location is unsafe',
      'Other (specify below)'
    ];

    final List<String> reasonsBengali = [
      'আমার অবস্থান থেকে অনেক দূরে',
      'ইতিমধ্যে অনেক কাজ আছে',
      'এই সময়ে পাওয়া যাচ্ছে না',
      'এই সেবা আমার দক্ষতায় নেই',
      'গ্রাহকের অবস্থান নিরাপদ নয়',
      'অন্যান্য (নিচে উল্লেখ করুন)'
    ];

    final reasons = isEnglish ? reasonsEnglish : reasonsBengali;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isEnglish ? 'Reject Job Request' : 'চাকরির অনুরোধ প্রত্যাখ্যান',
                  style: AppTextStyles.heading.copyWith(
                    color: Colors.red.shade600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish 
                    ? 'Please select a reason for rejecting this job request:'
                    : 'এই কাজের অনুরোধ প্রত্যাখ্যানের কারণ নির্বাচন করুন:',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 16),
                
                // Reason selection
                ...reasons.map((reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setDialogState(() => selectedReason = value),
                  title: Text(
                    reason,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )).toList(),
                
                // Custom reason text field (shown when "Other" is selected)
                if (selectedReason == reasons.last) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isEnglish 
                        ? 'Please specify your reason...'
                        : 'আপনার কারণ উল্লেখ করুন...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                customReasonController.dispose();
                Navigator.pop(context, {'confirmed': false});
              },
              child: Text(
                isEnglish ? 'Cancel' : 'বাতিল',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: selectedReason == null ? null : () {
                String finalReason = selectedReason!;
                
                // Use custom reason if "Other" is selected and text is provided
                if (selectedReason == reasons.last) {
                  final customText = customReasonController.text.trim();
                  if (customText.isNotEmpty) {
                    finalReason = customText;
                  }
                }
                
                customReasonController.dispose();
                Navigator.pop(context, {
                  'confirmed': true,
                  'reason': finalReason,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isEnglish ? 'Reject Job' : 'চাকরি প্রত্যাখ্যান',
              ),
            ),
          ],
        ),
      ),
    );
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

      _showBanner('Job completed successfully!', autoHide: true);
      
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
        
        // Always update local image first for immediate UI feedback
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _profileImage = null;
          });
        } else {
          setState(() {
            _profileImage = File(pickedFile.path);
            _webImage = null;
          });
        }
        
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _showBanner('Uploading to database...');
        
        // Try to upload to storage and update database
        try {
          print('📤 Starting upload process...');
          final bytes = kIsWeb ? _webImage! : await _profileImage!.readAsBytes();
          print('📦 Image bytes size: ${bytes.length}');
          
          final uploadedImageUrl = await _uploadImageToStorage(bytes, pickedFile.name);
          print('🔗 Upload result: $uploadedImageUrl');
          
          if (uploadedImageUrl != null) {
            print('✅ Upload successful, updating database...');
            // Successfully uploaded, update database
            await _updateProfile(newImageUrl: uploadedImageUrl);
            
            // Update local state to sync everywhere
            setState(() {
              mechanicImageUrl = uploadedImageUrl;
            });
            
            // Refresh profile data to ensure sync
            await _refreshProfileData();
            
            print('✅ Profile updated successfully with new image');
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            _showBanner('Profile picture updated successfully!', autoHide: true);
          } else {
            // Storage upload failed, try saving as base64 fallback
            print('⚠️ Storage failed, trying base64 fallback...');
            try {
              final base64Image = 'data:image/${pickedFile.name.split('.').last};base64,${base64Encode(bytes)}';
              await _updateProfile(newImageUrl: base64Image);
              
              setState(() {
                mechanicImageUrl = base64Image;
              });
              
              print('✅ Saved as base64 fallback');
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _showBanner('Profile picture updated (local storage)!', autoHide: true);
            } catch (base64Error) {
              print('❌ Base64 fallback also failed: $base64Error');
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _showBanner('Image updated locally only. Database save failed.', autoHide: true);
            }
          }
        } catch (uploadError) {
          print('❌ Upload/Database error: $uploadError');
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          _showBanner('Image updated locally. Cloud sync failed.', autoHide: true);
        }
      } else {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      _showBanner('Image selection failed. Please try again.');
      print('Image picker error: $e');
    }
  }
  
  Future<String?> _uploadImageToStorage(Uint8List bytes, String fileName) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ Upload failed: No authenticated user');
        return null;
      }
      
      print('📤 Starting image upload for user: ${user.id}');
      
      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last;
      final uniqueFileName = 'profile_${user.id}_$timestamp.$fileExtension';
      
      print('📁 Uploading to filename: $uniqueFileName');
      
      // Check if storage is available first
      try {
        final buckets = await supabase.storage.listBuckets();
        print('📦 Available buckets: ${buckets.map((b) => b.name).toList()}');
        
        if (buckets.isEmpty) {
          print('❌ No storage buckets found. Storage might not be configured.');
          return null;
        }
      } catch (listError) {
        print('❌ Failed to list buckets: $listError');
        // Continue anyway, try to upload
      }
      
      // Try to create and use a simple bucket approach
      try {
        // First try the most likely bucket name
        final imageUrl = await _tryUploadToBucket('avatars', uniqueFileName, bytes);
        if (imageUrl != null) return imageUrl;
        
        // Try alternative bucket names
        final bucketNames = ['profile-pictures', 'profiles', 'images', 'pictures'];
        for (String bucketName in bucketNames) {
          final url = await _tryUploadToBucket(bucketName, uniqueFileName, bytes);
          if (url != null) return url;
        }
        
        print('❌ All storage buckets failed');
        return null;
        
      } catch (storageError) {
        print('❌ Storage service error: $storageError');
        return null;
      }
      
    } catch (e) {
      print('❌ Image upload error: $e');
      return null;
    }
  }
  
  Future<String?> _tryUploadToBucket(String bucketName, String fileName, Uint8List bytes) async {
    try {
      print('🔄 Trying bucket: $bucketName');
      
      // Upload to Supabase storage
      await supabase.storage
          .from(bucketName)
          .uploadBinary(fileName, bytes);
      
      // Get public URL
      final imageUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);
      
      if (imageUrl.isNotEmpty) {
        print('✅ Successfully uploaded to bucket: $bucketName');
        print('🔗 Public URL: $imageUrl');
        return imageUrl;
      }
      
      return null;
    } catch (e) {
      print('❌ Failed bucket $bucketName: $e');
      return null;
    }
  }

  void _clearBanner() {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  void _showBanner(String message, {bool autoHide = false, Duration? duration}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: AppColors.primary.withOpacity(0.95),
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              _clearBanner();
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Auto-hide banner for success messages
    if (autoHide) {
      Future.delayed(duration ?? const Duration(seconds: 3), () {
        _clearBanner();
      });
    }
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
                    backgroundImage: mechanicImageUrl.isNotEmpty 
                        ? NetworkImage(mechanicImageUrl)
                        : _hasProfileImage() 
                            ? _getProfileImage()
                            : null,
                    child: (mechanicImageUrl.isEmpty && !_hasProfileImage()) 
                        ? Icon(Icons.person, color: Colors.white, size: 30)
                        : null,
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
            Colors.indigo.shade50,
            Colors.blue.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.indigo.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 5),
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.indigo.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Header Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade400,
                    Colors.blue.shade400,
                    Colors.cyan.shade400,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                // Profile Image with Enhanced Styling
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.withOpacity(0.1),
                                Colors.blue.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(4),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: Colors.indigo.shade50,
                                  backgroundImage: _hasProfileImage() 
                                      ? _getProfileImage()
                                      : null,
                                  child: !_hasProfileImage() ? Icon(
                                    Icons.person_rounded,
                                    size: 52,
                                    color: Colors.indigo.shade400,
                                  ) : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.indigo.shade400,
                                        Colors.blue.shade400,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
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
                const SizedBox(width: 24),
                // Profile Info with Enhanced Design
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name with enhanced styling
                      Text(
                        isLoadingProfile ? 'Loading...' : mechanicName,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 22,
                          fontFamily: AppFonts.primaryFont,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Professional Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade400,
                              Colors.blue.shade400,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              isEnglish ? 'Certified Mechanic' : 'প্রত্যয়িত মেকানিক',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Rating and Reviews with Enhanced Design
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade100,
                                  Colors.orange.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  isLoadingProfile ? '5.0' : mechanicRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: totalReviews > 0 ? () => _showReviewsScreen() : null,
                            onLongPress: () => _testDatabaseConnection(), // Debug: Long press to test database
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: totalReviews > 0 ? Colors.indigo.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: totalReviews > 0 ? Colors.indigo.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLoadingProfile 
                                        ? (isEnglish ? 'Loading...' : 'লোড হচ্ছে...')
                                        : isEnglish 
                                            ? '$totalReviews Reviews' 
                                            : '$totalReviews পর্যালোচনা',
                                    style: TextStyle(
                                      color: totalReviews > 0 ? Colors.indigo.shade600 : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (totalReviews > 0) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: Colors.indigo.shade600,
                                    ),
                                  ],
                                ],
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
        ],
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
    // Prioritize network image from database
    if (mechanicImageUrl.isNotEmpty) {
      if (mechanicImageUrl.startsWith('data:image/')) {
        // Handle base64 images
        final base64String = mechanicImageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } else {
        // Handle network URLs
        return NetworkImage(mechanicImageUrl);
      }
    }
    // Fall back to local images
    if (kIsWeb && _webImage != null) {
      return MemoryImage(_webImage!);
    } else if (!kIsWeb && _profileImage != null) {
      return FileImage(_profileImage!);
    }
    return null;
  }

  bool _hasProfileImage() {
    return mechanicImageUrl.isNotEmpty || 
           (kIsWeb && _webImage != null) || 
           (!kIsWeb && _profileImage != null);
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

// Reviews Dialog Widget
class ReviewsDialog extends StatefulWidget {
  final String mechanicId;
  final String mechanicName;
  final double mechanicRating;
  final int totalReviews;

  const ReviewsDialog({
    super.key,
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicRating,
    required this.totalReviews,
  });

  @override
  State<ReviewsDialog> createState() => _ReviewsDialogState();
}

class _ReviewsDialogState extends State<ReviewsDialog> {
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      setState(() {
        isLoading = true;
      });

      print('Fetching reviews for mechanic: ${widget.mechanicId}'); // Debug log

      // First, let's check if there are reviews at all for this mechanic
      final basicReviewsResponse = await supabase
          .from('reviews')
          .select('id, rating, mechanic_id, user_id')
          .eq('mechanic_id', widget.mechanicId);

      print('Basic reviews found: ${basicReviewsResponse.length}'); // Debug log
      if (basicReviewsResponse.isNotEmpty) {
        print('Sample basic review: ${basicReviewsResponse[0]}'); // Debug log
      }

      // Check if any reviews have user_id
      final reviewsWithUsers = basicReviewsResponse.where((r) => r['user_id'] != null).length;
      print('Reviews with user_id: $reviewsWithUsers out of ${basicReviewsResponse.length}'); // Debug log

      // Try to fetch detailed reviews with user information (optional join)
      final response = await supabase
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            user_id,
            mechanic_id,
            users(full_name, image_url)
          ''')
          .eq('mechanic_id', widget.mechanicId)
          .order('created_at', ascending: false);

      print('Detailed reviews fetched: ${response.length}'); // Debug log
      print('Sample detailed review: ${response.isNotEmpty ? response[0] : 'No data'}'); // Debug log

      setState(() {
        reviews = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

    } catch (e) {
      print('Error fetching reviews: $e');
      print('Stack trace: ${StackTrace.current}'); // More detailed error info
      
      // Try a simpler query without user join as fallback
      try {
        print('Attempting fallback query without user join...'); // Debug log
        final fallbackResponse = await supabase
            .from('reviews')
            .select('id, rating, comment, created_at, user_id, mechanic_id')
            .eq('mechanic_id', widget.mechanicId)
            .order('created_at', ascending: false);
        
        print('Fallback query successful: ${fallbackResponse.length} reviews'); // Debug log
        
        setState(() {
          reviews = List<Map<String, dynamic>>.from(fallbackResponse);
          isLoading = false;
        });
      } catch (fallbackError) {
        print('Fallback query also failed: $fallbackError'); // Debug log
        setState(() {
          isLoading = false;
          reviews = []; // Clear any existing data on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnglish = context.locale.languageCode == 'en';
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade600,
                    Colors.purple.shade600,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEnglish ? 'Customer Reviews' : 'গ্রাহক পর্যালোচনা',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Add refresh button
                      IconButton(
                        onPressed: isLoading ? null : _fetchReviews,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: isLoading ? Colors.white54 : Colors.white,
                        ),
                        tooltip: isEnglish ? 'Refresh Reviews' : 'পর্যালোচনা রিফ্রেশ করুন',
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Rating Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(
                              widget.mechanicRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < widget.mechanicRating.floor()
                                      ? Icons.star_rounded
                                      : index < widget.mechanicRating
                                          ? Icons.star_half_rounded
                                          : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.mechanicName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEnglish
                                    ? '${widget.totalReviews} reviews'
                                    : '${widget.totalReviews} পর্যালোচনা',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Reviews List
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : reviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rate_review_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isEnglish
                                    ? 'No reviews yet'
                                    : 'এখনও কোন পর্যালোচনা নেই',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isEnglish
                                    ? 'Reviews from customers will appear here'
                                    : 'গ্রাহকদের পর্যালোচনা এখানে দেখা যাবে',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            return _buildReviewCard(review, isEnglish);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isEnglish) {
    final DateTime reviewDate = DateTime.parse(review['created_at']);
    final String customerName = review['users']?['full_name'] ?? 'Anonymous Customer';
    final String customerImageUrl = review['users']?['image_url'] ?? '';
    final int rating = review['rating'] ?? 0;
    final String comment = review['comment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Customer Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: customerImageUrl.isNotEmpty
                    ? NetworkImage(customerImageUrl)
                    : null,
                child: customerImageUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        color: Colors.indigo.shade600,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Star rating
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getTimeAgo(reviewDate, isEnglish),
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime, bool isEnglish) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return isEnglish ? '$months month${months > 1 ? 's' : ''} ago' : '$months মাস আগে';
    } else if (difference.inDays > 0) {
      return isEnglish ? '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago' : '${difference.inDays} দিন আগে';
    } else if (difference.inHours > 0) {
      return isEnglish ? '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago' : '${difference.inHours} ঘন্টা আগে';
    } else if (difference.inMinutes > 0) {
      return isEnglish ? '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago' : '${difference.inMinutes} মিনিট আগে';
    } else {
      return isEnglish ? 'Just now' : 'এইমাত্র';
    }
  }
}