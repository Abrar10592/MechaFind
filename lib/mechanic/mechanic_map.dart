// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:mechfind/utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MechanicMap extends StatefulWidget {
  const MechanicMap({super.key});

  @override
  State<MechanicMap> createState() => _MechanicMapState();
}

class _MechanicMapState extends State<MechanicMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SupabaseClient supabase = Supabase.instance.client;
  latlng.LatLng? _currentLatLng;
  List<Marker> _sosMarkers = [];
  final String _mapboxAccessToken = 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
  bool _isLocationLoading = true;
  bool _isRequestsLoading = false;
  
  // Animation controllers for pulsating effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    
    _getUserLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLocationLoading = true;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocationLoading = false;
        });
        _showError("Location services are disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocationLoading = false;
          });
          _showError("Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocationLoading = false;
        });
        _showError("Location permissions are permanently denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Location access timed out'),
      );

      setState(() {
        _currentLatLng = latlng.LatLng(position.latitude, position.longitude);
        _isLocationLoading = false;
      });

      _mapController.move(_currentLatLng!, 14);
      await _loadNearbySOSRequests();
    } catch (e) {
      setState(() {
        _isLocationLoading = false;
      });
      _showError("Failed to fetch location");
      print('Error fetching location: $e');
    }
  }

  void _showError(String message) {
    // Convert technical errors to user-friendly messages
    String userMessage;
    if (message.contains('location') && message.contains('denied')) {
      userMessage = 'Location permission is required to show nearby requests';
    } else if (message.contains('service') && message.contains('disabled')) {
      userMessage = 'Please enable location services to continue';
    } else if (message.contains('network') || message.contains('connection')) {
      userMessage = 'Network issue. Please check your internet connection';
    } else if (message.contains('fetch') && message.contains('location')) {
      userMessage = 'Unable to get your location. Please try again';
    } else if (message.contains('SOS')) {
      userMessage = 'Unable to load nearby requests. Please try again';
    } else {
      userMessage = 'Something went wrong. Please try again';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (userMessage.contains('location')) {
              _getUserLocation();
            } else if (userMessage.contains('requests')) {
              _loadNearbySOSRequests();
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadNearbySOSRequests() async {
    if (_currentLatLng == null) {
      _showError("Current location not available");
      print('Cannot load SOS requests: Current location is null');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("Please log in to continue");
      print('Error: User not logged in');
      return;
    }

    setState(() {
      _isRequestsLoading = true;
    });

    try {
      // Fetch requests with same filters as mechanic landing screen PLUS accepted requests by this mechanic
      final response = await supabase
          .from('requests')
          .select('id, user_id, guest_id, vehicle, description, image, lat, lng, request_type, status, mechanic_id, users!left(full_name, phone, image_url)')
          .eq('request_type', 'emergency') // Only emergency requests
          .or('status.eq.pending,and(status.eq.accepted,mechanic_id.eq.${user.id})') // Pending requests OR accepted by this mechanic
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      print('Pending/Accepted SOS requests from Supabase: $response');

      // Fetch ignored requests for this mechanic (same as landing screen)
      final ignoredResponse = await supabase
          .from('ignored_requests')
          .select('request_id')
          .eq('mechanic_id', user.id);

      final ignoredRequestIds = ignoredResponse.map((item) => item['request_id'].toString()).toSet();

      const double maxDistanceKm = 10.0;
      final latlng.Distance distanceCalc = const latlng.Distance();

      List<Marker> filteredMarkers = [];
      List<Map<String, dynamic>> filteredRequestsData = [];

      for (var request in response) {
        try {
          final requestStatus = request['status'] ?? 'pending';
          final requestMechanicId = request['mechanic_id'];
          
          // For pending requests, skip ignored ones. For accepted requests, only show if assigned to this mechanic
          if (requestStatus == 'pending') {
            if (ignoredRequestIds.contains(request['id'].toString())) {
              continue; // Skip ignored pending requests
            }
            if (requestMechanicId != null) {
              continue; // Skip pending requests already assigned to someone
            }
          } else if (requestStatus == 'accepted') {
            if (requestMechanicId != user.id) {
              continue; // Skip accepted requests not assigned to this mechanic
            }
          } else {
            continue; // Skip requests with other statuses
          }
          
          final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
          final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
          
          // Valid location data filter (same as landing screen)
          if (lat == 0.0 || lng == 0.0) continue;
          
          final point = latlng.LatLng(lat, lng);
          final distance = distanceCalc.as(
            latlng.LengthUnit.Kilometer,
            _currentLatLng!,
            point,
          );

          // Distance filter (same as landing screen)
          if (distance <= maxDistanceKm) {
            // Valid user data filter (same as landing screen)
            if (request['user_id'] == null && request['guest_id'] == null) {
              // Invalid request - skip
              continue;
            }
            
            // Store request data with proper user handling
            Map<String, dynamic> processedRequest = {
              'id': request['id'],
              'vehicle': request['vehicle'],
              'description': request['description'],
              'image': request['image'],
              'lat': lat,
              'lng': lng,
              'request_type': request['request_type'] ?? 'emergency',
              'status': requestStatus,
              'mechanic_id': requestMechanicId,
              'distance': distance,
            };
            
            // Handle both guest and authenticated user requests (same as landing screen)
            if (request['user_id'] != null) {
              // Authenticated user request
              processedRequest['user_id'] = request['user_id'];
              processedRequest['guest_id'] = null;
              final fullName = request['users']?['full_name'];
              final phone = request['users']?['phone'];
              final imageUrl = request['users']?['image_url'];
              
              processedRequest['user_name'] = fullName ?? 'Unknown User';
              processedRequest['phone'] = phone ?? 'N/A';
              processedRequest['image_url'] = imageUrl;
            } else if (request['guest_id'] != null) {
              // Guest request
              processedRequest['user_id'] = null;
              processedRequest['guest_id'] = request['guest_id'];
              processedRequest['user_name'] = 'Guest User';
              processedRequest['phone'] = 'Contact via app';
              processedRequest['image_url'] = null;
            }
            
            filteredRequestsData.add(processedRequest);
            
            // Create marker using processed data with different styling based on status
            final isAccepted = requestStatus == 'accepted';
            
            filteredMarkers.add(
              Marker(
                point: point,
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _buildEnhancedRequestDetails(processedRequest),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isAccepted ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 23,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: (processedRequest['image_url'] != null && 
                                processedRequest['image_url'].toString().isNotEmpty)
                                ? NetworkImage(processedRequest['image_url'])
                                : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
                          ),
                        ),
                        // Add accepted indicator
                        if (isAccepted)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        } catch (e) {
          print('Error processing request marker: $e');
        }
      }

      setState(() {
        _sosMarkers = filteredMarkers;
        _isRequestsLoading = false;
      });
      print('Filtered SOS markers (pending + accepted): ${filteredMarkers.length}');
    } catch (e) {
      setState(() {
        _isRequestsLoading = false;
      });
      _showError("Error fetching SOS requests");
      print('Error fetching SOS requests: $e');
    }
  }

  Future<String> _getPlaceName(double lat, double lng) async {
    final url = 'https://api.mapbox.com/search/geocode/v6/reverse?longitude=$lng&latitude=$lat&types=address,place&access_token=$_mapboxAccessToken';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Mapbox API response: $data');
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final feature = features[0]['properties'];
          return feature['full_address'] ?? feature['name'] ?? 'Unknown location';
        }
        return 'Unknown location';
      } else {
        print('Mapbox API error: ${response.statusCode} ${response.body}');
        return '($lat, $lng)';
      }
    } catch (e) {
      print('Error fetching place name: $e');
      return '($lat, $lng)';
    }
  }

  Widget _buildEnhancedRequestDetails(Map<String, dynamic> data) {
    final lat = double.tryParse(data['lat']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(data['lng']?.toString() ?? '') ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Header section
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: (data['image_url'] != null && 
                            data['image_url'].toString().isNotEmpty)
                            ? NetworkImage(data['image_url'])
                            : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['user_name'] ?? 'Unknown User',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: FontSizes.subHeading + 2,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (data['status'] == 'accepted' ? Colors.green : Colors.red).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            data['status'] == 'accepted' ? 'Accepted by You' : 'Emergency Request',
                            style: TextStyle(
                              color: data['status'] == 'accepted' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: FontSizes.caption,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Problem image
              if (data['image'] != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      data['image'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Details section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade50,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildEnhancedInfoRow(Icons.directions_car_rounded, "Vehicle", data['vehicle'] ?? 'Unknown'),
                    const SizedBox(height: 16),
                    _buildEnhancedInfoRow(Icons.build_circle_outlined, "Problem", data['description'] ?? 'No description'),
                    const SizedBox(height: 16),
                    FutureBuilder<String>(
                      future: _getPlaceName(lat, lng),
                      builder: (context, snapshot) {
                        String locationText;
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          locationText = 'Loading location...';
                        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          locationText = '(${data['lat']}, ${data['lng']})';
                        } else {
                          locationText = snapshot.data!;
                        }
                        return _buildEnhancedInfoRow(Icons.location_on_rounded, "Location", locationText);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildEnhancedInfoRow(Icons.phone_rounded, "Phone", data['phone'] ?? 'Not available'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons - different based on request status
              if (data['status'] == 'accepted')
                // Accepted request buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green,
                              Colors.green.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Navigate to active request page or start navigation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Navigate to request location'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.navigation_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Navigate',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: FontSizes.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Mark as complete
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mark request as completed'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Complete',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: FontSizes.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Pending request buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Add accept request logic here
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Accept request functionality will be implemented'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            'Accept Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: FontSizes.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.grey.shade600,
                        iconSize: 28,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: FontSizes.caption,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = EasyLocalization.of(context)?.locale.languageCode ?? 'en';
    final isEnglish = currentLang == 'en';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          'nearby_sos_requests'.tr(),
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.subHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              onPressed: () {
                _loadNearbySOSRequests();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng ?? latlng.LatLng(23.8041, 90.4152),
              initialZoom: 14,
              minZoom: 0,
              maxZoom: 100,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ",
                additionalOptions: {
                  'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ',
                  'id': 'mapbox.mapbox-traffic-v1',
                },
              ),
              // Custom pulsating current location marker
              if (_currentLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer pulsating circle
                              Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // Inner static circle
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              // SOS request markers with data
              MarkerLayer(markers: _sosMarkers),
            ],
          ),
          // Loading overlay
          if (_isLocationLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading map and getting your location...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Requests loading indicator
          if (_isRequestsLoading && !_isLocationLoading)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading nearby requests...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLatLng != null) {
            _mapController.move(_currentLatLng!, _mapController.camera.zoom);
          } else {
            _getUserLocation();
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white, size: 35),
      ),
    );
  }
}