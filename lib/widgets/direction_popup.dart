import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:mechfind/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'message_screen.dart';


class DirectionPopup extends StatefulWidget {
  final latlng.LatLng requestLocation;
  final String phone;
  final String name;
  final VoidCallback onReject;

  const DirectionPopup({
    super.key,
    required this.requestLocation,
    required this.phone,
    required this.name,
    required this.onReject,
  });

  @override
  State<DirectionPopup> createState() => _DirectionPopupState();
}

class _DirectionPopupState extends State<DirectionPopup> {
  final MapController _mapController = MapController();
  final Location _location = Location();

  latlng.LatLng? _mechanicLocation;
  List<List<latlng.LatLng>> _routes = [];
  StreamSubscription<LocationData>? _locationSubscription;

  double _currentZoom = 14;
  bool _userMovedMap = false;
  double? _distanceInMeters;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locData = await _location.getLocation();
    _updateMechanicLocation(locData);

    _locationSubscription = _location.onLocationChanged.listen((locData) {
      _updateMechanicLocation(locData);
    });
  }

  void _updateMechanicLocation(LocationData locData) {
    final newLoc = latlng.LatLng(locData.latitude!, locData.longitude!);
    setState(() {
      _mechanicLocation = newLoc;
    });

    if (!_userMovedMap) {
      _mapController.move(newLoc, _currentZoom);
    }

    _fetchRoutes(newLoc, widget.requestLocation);
  }

  Future<void> _fetchRoutes(latlng.LatLng start, latlng.LatLng end) async {
    final accessToken =
        'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?geometries=geojson&overview=full&alternatives=true&access_token=$accessToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;

        if (routes.isEmpty) {
          debugPrint('No routes found');
          return;
        }

        List<List<latlng.LatLng>> parsedRoutes = [];
        double? minDistance;

        for (var route in routes) {
          final coords = route['geometry']['coordinates'] as List;
          final points = coords
              .map((c) => latlng.LatLng(c[1] as double, c[0] as double))
              .toList();
          parsedRoutes.add(points);

          final dist = route['distance'] as double;
          if (minDistance == null || dist < minDistance) {
            minDistance = dist;
          }
        }

        setState(() {
          _routes = parsedRoutes;
          _distanceInMeters = minDistance;
        });
      } else {
        debugPrint('Failed to get routes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    }
  }

  void _launchPhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Reject Request", style: AppTextStyles.heading),
        content: Text("Are you sure you want to reject this request?", style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              widget.onReject();
            },
            child: Text("Yes", style: AppTextStyles.label),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessToken =
        'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _showConfirmationDialog,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => _userMovedMap = true,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              _mechanicLocation ?? widget.requestLocation,
                          initialZoom: _currentZoom,
                          onPositionChanged: (MapCamera camera, bool hasGesture) {
                            if (hasGesture) {
                              _currentZoom = camera.zoom;
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken",
                            additionalOptions: {
                              'accessToken': accessToken,
                              'id': 'mapbox.mapbox-traffic-v1',
                            },
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.requestLocation,
                                width: 60,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(2, 2),
                                      )
                                    ],
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset('zob_assets/user_icon.png'),
                                  ),
                                ),
                              ),
                              if (_mechanicLocation != null)
                                Marker(
                                  point: _mechanicLocation!,
                                  width: 60,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        )
                                      ],
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.asset('zob_assets/mechanic_icon.png'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          for (final route in _routes)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: route,
                                  strokeWidth: 5.0,
                                  color: route == _routes.first
                                      ? AppColors.accent
                                      : AppColors.accent.withValues(alpha: 0.3),
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 1.0,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
              if (_distanceInMeters != null)
                Positioned(
                  top: 60,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      '${(_distanceInMeters! / 1000).toStringAsFixed(2)} km',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Positioned(
                bottom: 100,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    if (_mechanicLocation != null) {
                      _userMovedMap = false;
                      _mapController.move(_mechanicLocation!, _currentZoom);
                    }
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchPhoneCall(widget.phone),
                          icon: const Icon(Icons.call),
                          label: Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            textStyle: AppTextStyles.label,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MessageScreen(name: widget.name),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            textStyle: AppTextStyles.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
