// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
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

class _MechanicMapState extends State<MechanicMap> {
  final MapController _mapController = MapController();
  final SupabaseClient supabase = Supabase.instance.client;
  latlng.LatLng? _currentLatLng;
  List<Marker> _sosMarkers = [];
  final String _mapboxAccessToken = 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
  bool _isLocationLoading = true;
  bool _isRequestsLoading = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
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
      final response = await supabase
          .from('requests')
          .select('id, user_id, vehicle, description, image, lat, lng, users!left(full_name, phone, image_url)')
          .eq('status', 'pending')
          .filter('mechanic_id', 'is', null)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      print('Pending requests from Supabase: $response');

      const double maxDistanceKm = 10.0;
      final latlng.Distance distanceCalc = const latlng.Distance();

      List<Marker> filteredMarkers = response
          .map<Marker?>((request) {
            try {
              final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
              final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
              
              if (lat == 0.0 || lng == 0.0) return null;
              
              final point = latlng.LatLng(lat, lng);
              final distance = distanceCalc.as(
                latlng.LengthUnit.Kilometer,
                _currentLatLng!,
                point,
              );

              if (distance <= maxDistanceKm) {
                return Marker(
                  point: point,
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _buildRequestDetails(request),
                      );
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: CircleAvatar(
                        radius: 27,
                        backgroundImage: (request['users']?['image_url'] != null && 
                            request['users']['image_url'].toString().isNotEmpty)
                            ? NetworkImage(request['users']['image_url'])
                            : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
                      ),
                    ),
                  ),
                );
              }
              return null;
            } catch (e) {
              print('Error processing request marker: $e');
              return null;
            }
          })
          .whereType<Marker>()
          .toList();

      setState(() {
        _sosMarkers = filteredMarkers;
        _isRequestsLoading = false;
      });
      print('Filtered SOS markers: ${filteredMarkers.length}');
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

  Widget _buildRequestDetails(Map<String, dynamic> data) {
    final lat = double.tryParse(data['lat']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(data['lng']?.toString() ?? '') ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                data['image'] ?? data['users']?['image_url'] ?? 'https://via.placeholder.com/300',
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'zob_assets/user_icon.png',
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              data['users']?['full_name'] ?? 'Unknown',
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.subHeading + 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.directions_car, "Car", data['vehicle'] ?? 'Unknown'),
                  _buildInfoRow(Icons.build_circle_outlined, "Issue", data['description'] ?? 'No description'),
                  FutureBuilder<String>(
                    future: _getPlaceName(lat, lng),
                    builder: (context, snapshot) {
                      String locationText;
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        locationText = 'Fetching location...';
                      } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        locationText = '(${data['lat']}, ${data['lng']})';
                      } else {
                        locationText = snapshot.data!;
                      }
                      return _buildInfoRow(Icons.location_on_outlined, "Location", locationText);
                    },
                  ),
                  _buildInfoRow(Icons.phone, "Phone", data['users']?['phone'] ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = EasyLocalization.of(context)?.locale.languageCode ?? 'en';
    final isEnglish = currentLang == 'en';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'nearby_sos_requests'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.subHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
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
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: const DefaultLocationMarker(
                    child: Icon(Icons.my_location, color: Colors.white),
                  ),
                  markerSize: const Size(35, 35),
                  markerDirection: MarkerDirection.heading,
                ),
              ),
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