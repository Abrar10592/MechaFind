import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
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
  List<latlng.LatLng> _routePoints = [];
  StreamSubscription<LocationData>? _locationSubscription;

  double _currentZoom = 14;

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

    _mapController.move(newLoc, _currentZoom);

    _fetchRoute(newLoc, widget.requestLocation);
  }

  Future<void> _fetchRoute(latlng.LatLng start, latlng.LatLng end) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final coords = json['routes'][0]['geometry']['coordinates'] as List;

        List<latlng.LatLng> points = coords
            .map((c) => latlng.LatLng(c[1] as double, c[0] as double))
            .toList();

        setState(() {
          _routePoints = points;
        });
      } else {
        debugPrint('Failed to get route: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
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
        title: const Text("Reject Request"),
        content: const Text("Are you sure you want to reject this request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dismiss dialog
              Navigator.of(context).pop(); // dismiss bottom sheet
              widget.onReject();
            },
            child: const Text("Yes"),
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
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Close button with confirmation
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

            // Map view
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mechanicLocation ?? widget.requestLocation,
                  initialZoom: _currentZoom,
                  onPositionChanged: (MapCamera camera, bool hasGesture) {
                    setState(() {
                      _currentZoom = camera.zoom;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://api.mapbox.com/styles/v1/adil420/cmdj97xhm005z01s8gos7f5m1/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRqNWI5Z3QwanI3Mm1wemhsdWRwejNnIn0.rt01emLkip-tPmEJbN3C4g",
                    additionalOptions: {
                      'accessToken':
                          'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRqNWI5Z3QwanI3Mm1wemhsdWRwejNnIn0.rt01emLkip-tPmEJbN3C4g',
                      'id':
                          'mapbox.mapbox-traffic-v1', // or mapbox/satellite-v9, etc.
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.requestLocation,
                        width: 40,
                        height: 40,
                        child: Image.asset(
                          'zob_assets/mechanic_icon.png',
                          width: 50,
                          height: 50,
                          color: const Color.fromARGB(255, 91, 79, 20),
                        ),
                      ),
                      if (_mechanicLocation != null)
                        Marker(
                          point: _mechanicLocation!,
                          width: 40,
                          height: 40,
                          child: Image.asset(
                            'zob_assets/user_icon.png',
                            width: 50,
                            height: 50,
                            color: const Color.fromARGB(255, 40, 97, 240),
                          ),
                        ),
                    ],
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Buttons (Call & Message)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchPhoneCall(widget.phone),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
