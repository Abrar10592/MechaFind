import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:mechfind/data/demo_data.dart';
import 'package:mechfind/utils.dart';
import 'package:easy_localization/easy_localization.dart';

class MechanicMap extends StatefulWidget {
  const MechanicMap({super.key});

  @override
  State<MechanicMap> createState() => _MechanicMapState();
}

class _MechanicMapState extends State<MechanicMap> {
  final MapController _mapController = MapController();
  latlng.LatLng? _currentLatLng;
  List<Marker> _sosMarkers = [];

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

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLatLng = latlng.LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_currentLatLng!, 14);
    _loadNearbySOSRequests();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _loadNearbySOSRequests() {
    const double maxDistanceKm = 7.0;
    final latlng.Distance distanceCalc = const latlng.Distance();

    List<Marker> filteredMarkers = demoData
        .map((data) {
          latlng.LatLng point = latlng.LatLng(data['lat'], data['lng']);
          double distance = distanceCalc.as(
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
                    builder: (_) => _buildRequestDetails(data),
                  );
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: CircleAvatar(
                    radius: 27,
                    backgroundImage: NetworkImage(data['photo_url']),
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
  }

  Widget _buildRequestDetails(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                data['profile_url'],
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data['user_name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text("Car: ${data['car_model']}"),
            Text("Issue: ${data['issue_description']}"),
            Text("Location: ${data['location']}"),
            Text("Phone: ${data['phone']}"),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEnglish ? 'Nearby SOS Requests' : 'কাছাকাছি এসওএস অনুরোধ',
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
                    "https://api.mapbox.com/styles/v1/adil420/cmdj97xhm005z01s8gos7f5m1/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRqNWI5Z3QwanI3Mm1wemhsdWRwejNnIn0.rt01emLkip-tPmEJbN3C4g",
                additionalOptions: {
                  'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRqNWI5Z3QwanI3Mm1wemhsdWRwejNnIn0.rt01emLkip-tPmEJbN3C4g',
                  'id': 'mapbox.mapbox-traffic-v1', // or mapbox/satellite-v9, etc.
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
