import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class FindMechanicService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all registered mechanics from database
  static Future<List<Map<String, dynamic>>> fetchAllMechanics({
    double? userLat,
    double? userLng,
    String? searchQuery,
  }) async {
    try {
      final response = await _supabase
          .from('users')
          .select('''
            id,
            full_name,
            phone,
            email,
            image_url,
            role
          ''')
          .eq('role', 'mechanic');

      if (response.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> mechanicsList = [];

      for (final user in response) {
        // Apply search filter if provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final fullName = (user['full_name'] ?? '').toString().toLowerCase();
          if (!fullName.contains(searchQuery.toLowerCase())) {
            continue;
          }
        }

        // Try to get mechanic-specific data (rating, location) - this is optional
        Map<String, dynamic>? mechanicData;
        try {
          final mechanicResponse = await _supabase
              .from('mechanics')
              .select('rating, location_x, location_y, fcm_token')
              .eq('id', user['id'])
              .maybeSingle();
          mechanicData = mechanicResponse;
        } catch (e) {
          mechanicData = null;
        }

        final mechLat = mechanicData != null ? (mechanicData['location_x'] as num?)?.toDouble() : null;
        final mechLng = mechanicData != null ? (mechanicData['location_y'] as num?)?.toDouble() : null;

        // Calculate distance if user location is available
        double? distance;
        String distanceStr = 'Unknown';
        String responseTime = '10 min';
        
        if (userLat != null && userLng != null && mechLat != null && mechLng != null) {
          distance = _calculateDistance(userLat, userLng, mechLat, mechLng);
          distanceStr = '${distance.toStringAsFixed(1)} km';
          responseTime = _calculateResponseTime(distance);
        }

        // Fetch services for this mechanic (optional)
        List<String> services = [];
        try {
          services = await _fetchMechanicServices(user['id']);
        } catch (e) {
          services = ['General Repair']; // Default service
        }

        // Get reviews data (count and average rating)
        Map<String, dynamic> reviewsData = {'count': 0, 'averageRating': 0.0};
        try {
          reviewsData = await _getMechanicReviewsData(user['id']);
        } catch (e) {
          // Default to no reviews
        }

        // Calculate actual rating - prioritize reviews average, fallback to mechanic table
        double actualRating = 0.0;
        if (reviewsData['averageRating'] > 0) {
          actualRating = reviewsData['averageRating'];
        } else if (mechanicData != null && mechanicData['rating'] != null) {
          actualRating = (mechanicData['rating'] as num?)?.toDouble() ?? 0.0;
        }

        // Determine online status based on recent activity
        bool isOnline = false;
        try {
          isOnline = await _checkMechanicOnlineStatus(user['id']);
        } catch (e) {
          // Default to offline if can't determine
        }

        final mechanicCard = {
          'id': user['id'],
          'name': user['full_name'] ?? 'Unknown Mechanic',
          'address': mechLat != null && mechLng != null 
              ? await _getAddressFromLatLng(mechLat, mechLng, user['id'])
              : 'Location not set',
          'distance': distanceStr,
          'distance_value': distance ?? 999999, // Put mechanics without location at end
          'rating': actualRating,
          'reviews': reviewsData['count'] as int,
          'response': responseTime,
          'services': services,
          'online': isOnline,
          'phone': user['phone'] ?? '',
          'email': user['email'] ?? '',
          'image_url': user['image_url'],
          'fcm_token': mechanicData?['fcm_token'],
          'latitude': mechLat,
          'longitude': mechLng,
        };

        mechanicsList.add(mechanicCard);
      }

      // Sort by distance (mechanics without location will be at the end)
      mechanicsList.sort((a, b) {
        final distanceA = a['distance_value'] as double;
        final distanceB = b['distance_value'] as double;
        return distanceA.compareTo(distanceB);
      });

      return mechanicsList;
    } catch (e) {
      return [];
    }
  }

  /// Fetch mechanics from database based on user location (for backward compatibility)
  static Future<List<Map<String, dynamic>>> fetchMechanicsNearby({
    required double userLat,
    required double userLng,
    double maxDistanceKm = 50.0, // Increased default radius
    String? searchQuery,
  }) async {
    final allMechanics = await fetchAllMechanics(
      userLat: userLat,
      userLng: userLng,
      searchQuery: searchQuery,
    );

    // Filter by distance if location is available
    return allMechanics.where((mechanic) {
      final distance = mechanic['distance_value'] as double;
      return distance <= maxDistanceKm;
    }).toList();
  }

  /// Calculate distance between two coordinates in kilometers
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);

  /// Fetch services for a specific mechanic
  static Future<List<String>> _fetchMechanicServices(String mechanicId) async {
    try {
      final response = await _supabase
          .from('mechanic_services')
          .select('services(name)')
          .eq('mechanic_id', mechanicId);

      return response
          .map((item) => item['services']?['name'] as String?)
          .where((name) => name != null)
          .cast<String>()
          .toList();
    } catch (e) {
      // Return some default services if the table doesn't exist or query fails
      return ['General Repair', 'Maintenance'];
    }
  }

  /// Get reviews count and average rating for a mechanic
  static Future<Map<String, dynamic>> _getMechanicReviewsData(String mechanicId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('id, rating')
          .eq('mechanic_id', mechanicId);
      
      if (response.isEmpty) {
        return {'count': 0, 'averageRating': 0.0};
      }
      
      final ratings = response
          .map((review) => (review['rating'] as num?)?.toDouble() ?? 0.0)
          .where((rating) => rating > 0)
          .toList();
      
      final averageRating = ratings.isEmpty 
          ? 0.0 
          : ratings.reduce((a, b) => a + b) / ratings.length;
      
      return {
        'count': response.length,
        'averageRating': averageRating,
      };
    } catch (e) {
      return {'count': 0, 'averageRating': 0.0};
    }
  }

  /// Get detailed reviews for a mechanic (for profile display)
  static Future<List<Map<String, dynamic>>> getMechanicReviews(String mechanicId, {int limit = 10}) async {
    try {
      // First get the reviews
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('id, user_id, rating, comment, created_at')
          .eq('mechanic_id', mechanicId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (reviewsResponse.isEmpty) {
        return [];
      }

      // Get user IDs from reviews
      final userIds = reviewsResponse
          .map((review) => review['user_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch user data for all reviewers
      final usersResponse = userIds.isNotEmpty
          ? await _supabase
              .from('users')
              .select('id, full_name, image_url')
              .inFilter('id', userIds)
          : <Map<String, dynamic>>[];

      // Create a map of user data for quick lookup
      final usersMap = Map.fromIterable(
        usersResponse,
        key: (user) => user['id'],
        value: (user) => user,
      );

      // Combine review and user data
      return reviewsResponse.map((review) {
        final userId = review['user_id'];
        final userData = usersMap[userId];
        
        return {
          'id': review['id'],
          'rating': (review['rating'] as num?)?.toDouble() ?? 0.0,
          'review': review['comment'] ?? '',
          'created_at': review['created_at'],
          'user_name': userData?['full_name'] ?? 'Anonymous User',
          'user_image': userData?['image_url'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  /// Check if mechanic is online based on recent activity
  static Future<bool> _checkMechanicOnlineStatus(String mechanicId) async {
    try {
      // Check if mechanic has been active recently in the last 2 hours
      final recentActivity = DateTime.now().subtract(const Duration(hours: 2));
      
      // Check for recent requests accepted or completed
      final recentRequests = await _supabase
          .from('requests')
          .select('created_at')
          .eq('mechanic_id', mechanicId)
          .gte('updated_at', recentActivity.toIso8601String())
          .limit(1);
      
      if (recentRequests.isNotEmpty) {
        return true;
      }
      
      // Alternative: Check if mechanic is in the mechanics table with active status
      // You can add an 'active' or 'last_seen' column to mechanics table for better tracking
      final mechanicStatus = await _supabase
          .from('mechanics')
          .select('fcm_token')
          .eq('id', mechanicId)
          .maybeSingle();
      
      // If mechanic has FCM token, consider them potentially online
      return mechanicStatus?['fcm_token'] != null;
      
    } catch (e) {
      // Default to false if can't determine
      return false;
    }
  }

  /// Calculate estimated response time based on distance
  static String _calculateResponseTime(double distanceKm) {
    // Simple logic: 1 km = 2 minutes, minimum 5 minutes
    final minutes = math.max(5, (distanceKm * 2).round());
    return '$minutes min';
  }

  /// Get address from coordinates or database
  static Future<String> _getAddressFromLatLng(double lat, double lng, String? mechanicId) async {
    try {
      // First try to get address from user/mechanic profile if available
      if (mechanicId != null) {
        final addressData = await _supabase
            .from('users')
            .select('address')
            .eq('id', mechanicId)
            .maybeSingle();
        
        if (addressData != null && 
            addressData['address'] != null && 
            addressData['address'].toString().isNotEmpty) {
          return addressData['address'];
        }
      }
      
      // Fallback: You can implement reverse geocoding here with a service like Google Maps
      // For now, return formatted coordinates
      return 'Near ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } catch (e) {
      return 'Location unavailable';
    }
  }

  /// Get mechanic details by ID
  static Future<Map<String, dynamic>?> getMechanicById(String mechanicId) async {
    try {
      final response = await _supabase
          .from('mechanics')
          .select('''
            id,
            rating,
            location_x,
            location_y,
            image_url,
            fcm_token,
            users!inner(
              full_name,
              phone,
              email,
              image_url
            )
          ''')
          .eq('id', mechanicId)
          .single();

      final userData = response['users'] as Map<String, dynamic>;
      final services = await _fetchMechanicServices(mechanicId);
      final reviewsData = await _getMechanicReviewsData(mechanicId);
      
      // Calculate actual rating - prioritize reviews average, fallback to mechanic table
      double actualRating = 0.0;
      if (reviewsData['averageRating'] > 0) {
        actualRating = reviewsData['averageRating'];
      } else if (response['rating'] != null) {
        actualRating = (response['rating'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'id': response['id'],
        'name': userData['full_name'] ?? 'Unknown Mechanic',
        'phone': userData['phone'] ?? '',
        'email': userData['email'] ?? '',
        'image_url': userData['image_url'] ?? response['image_url'],
        'rating': actualRating,
        'reviews': reviewsData['count'] as int,
        'services': services,
        'latitude': (response['location_x'] as num?)?.toDouble(),
        'longitude': (response['location_y'] as num?)?.toDouble(),
        'fcm_token': response['fcm_token'],
      };
    } catch (e) {
      return null;
    }
  }
}
