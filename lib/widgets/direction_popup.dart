import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:mechfind/mechanic/chat_screen.dart';

import 'package:mechfind/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectionPopup extends StatefulWidget {
  final latlng.LatLng requestLocation;
  final String phone;
  final String name;
  final String requestId;
  final String user_id;
  final VoidCallback onReject;
  final String imageUrl;
  final VoidCallback onMinimize;

  const DirectionPopup({
    super.key,
    required this.requestLocation,
    required this.phone,
    required this.name,
    required this.requestId,
    required this.onReject,
    required this.onMinimize,
    required this.user_id,
    this.imageUrl = '',
  });

  @override
  State<DirectionPopup> createState() => _DirectionPopupState();
}

class _DirectionPopupState extends State<DirectionPopup> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final SupabaseClient supabase = Supabase.instance.client;

  latlng.LatLng? _mechanicLocation;
  List<List<latlng.LatLng>> _routes = [];
  StreamSubscription<LocationData>? _locationSubscription;

  double _currentZoom = 14;
  bool _userMovedMap = false;
  double? _distanceInMeters;
  bool _isLoadingRoute = false;
  double? _mechanicHeading; // Direction the mechanic is facing

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
      _mechanicHeading = locData.heading; // Capture the direction user is facing
    });

    if (!_userMovedMap) {
      _mapController.move(newLoc, _currentZoom);
    }

    _fetchRoutes(newLoc, widget.requestLocation);
  }

  Future<void> _fetchRoutes(latlng.LatLng start, latlng.LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });

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
          setState(() {
            _isLoadingRoute = false;
          });
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
          _isLoadingRoute = false;
        });
      } else {
        debugPrint('Failed to get routes: ${response.statusCode}');
        setState(() {
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
      setState(() {
        _isLoadingRoute = false;
      });
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
        content: Text(
          "Are you sure you want to reject this request?",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('requests')
                    .update({
                      'mechanic_id': null,
                      'status': 'pending',
                      'mech_lat': null,
                      'mech_lng': null,
                    })
                    .eq('id', widget.requestId);
                print(
                  'Request ${widget.requestId} rejected: Cleared mechanic_id, mech_lat, mech_lng, and set status to pending',
                );
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close modal
                widget.onReject(); // Trigger UI update in MechanicLandingScreen
              } catch (e) {
                print('Error rejecting request ${widget.requestId}: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error rejecting request: $e')),
                );
              }
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
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.1) {
          widget.onMinimize();
          _locationSubscription?.pause();
          print('Modal minimized to bubble, location subscription paused');
        } else {
          if (_locationSubscription?.isPaused ?? false) {
            _locationSubscription?.resume();
            print('Modal restored, location subscription resumed');
          }
        }
        return true;
      },
      child: SafeArea(
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
                            onPositionChanged:
                                (MapCamera camera, bool hasGesture) {
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
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.asset(
                                        'zob_assets/user_icon.png',
                                      ),
                                    ),
                                  ),
                                ),
                                if (_mechanicLocation != null)
                                  Marker(
                                    point: _mechanicLocation!,
                                    width: 60,
                                    height: 60,
                                    child: Stack(
                                      children: [
                                        // Blue shadow indicating direction (background layer)
                                        if (_mechanicHeading != null && _mechanicHeading! >= 0)
                                          Transform.rotate(
                                            angle: (_mechanicHeading! * 3.14159) / 180,
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  center: const Alignment(0, -0.3), // Offset towards heading direction
                                                  radius: 0.8,
                                                  colors: [
                                                    Colors.blue.withOpacity(0.4),
                                                    Colors.blue.withOpacity(0.2),
                                                    Colors.blue.withOpacity(0.1),
                                                    Colors.transparent,
                                                  ],
                                                  stops: const [0.0, 0.4, 0.7, 1.0],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        // Main mechanic marker (foreground layer)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(2, 2),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.asset(
                                              'zob_assets/mechanic_icon.png',
                                            ),
                                          ),
                                        ),
                                        // Direction arrow (top layer)
                                        if (_mechanicHeading != null && _mechanicHeading! >= 0)
                                          Positioned(
                                            top: -5,
                                            right: -5,
                                            child: Transform.rotate(
                                              angle: (_mechanicHeading! * 3.14159) / 180, // Convert degrees to radians
                                              child: Container(
                                                width: 25,
                                                height: 25,
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.navigation,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
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
                                        : AppColors.accent.withValues(
                                            alpha: 0.3,
                                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        '${(_distanceInMeters! / 1000).toStringAsFixed(2)} km',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Loading indicator for route calculation
                if (_isLoadingRoute)
                  Positioned(
                    top: 100,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Calculating route...',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
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
                                  builder: (_) => ChatScreen(
                                    receiverId: widget.user_id,
                                    receiverName: widget.name,
                                    receiverImageUrl:widget.imageUrl,
                                        
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message),
                            label: const Text("Message"),
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
      ),
    );
  }
}
