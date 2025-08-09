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

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError("Location permissions are permanently denied.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLatLng = latlng.LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_currentLatLng!, 14);
      await _loadNearbySOSRequests();
    } catch (e) {
      _showError("Failed to fetch location: $e");
      print('Error fetching location: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadNearbySOSRequests() async {
    if (_currentLatLng == null) {
      _showError("Current location not available.");
      print('Cannot load SOS requests: Current location is null');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("User not logged in.");
      print('Error: User not logged in');
      return;
    }

    try {
      final response = await supabase
          .from('requests')
          .select('id, user_id, vehicle, description, image, lat, lng, users!left(full_name, phone, image_url)')
          .eq('status', 'pending')
          .filter('mechanic_id', 'is', null);

      print('Pending requests from Supabase: $response');

      const double maxDistanceKm = 7.0;
      final latlng.Distance distanceCalc = const latlng.Distance();

      List<Marker> filteredMarkers = response
          .map<Marker?>((request) {
            final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
            final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
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
                      backgroundImage: request['users']?['image_url'] != null
                          ? NetworkImage(request['users']['image_url'])
                          : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
                    ),
                  ),
                ),
              );
            }
            return null;
          })
          .whereType<Marker>()
          .toList();

      setState(() {
        _sosMarkers = filteredMarkers;
      });
      print('Filtered SOS markers: ${filteredMarkers.length}');
    } catch (e) {
      _showError("Error fetching SOS requests: $e");
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
        return '(${lat}, ${lng})';
      }
    } catch (e) {
      print('Error fetching place name: $e');
      return '(${lat}, ${lng})';
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