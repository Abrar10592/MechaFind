import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MechanicMap extends StatefulWidget {
  const MechanicMap({super.key});

  @override
  State<MechanicMap> createState() => _MechanicMapState();
}

class _MechanicMapState extends State<MechanicMap> with WidgetsBindingObserver {
  final Location _locationController = Location();
  static const LatLng _defaultLocation = LatLng(23.8041, 90.4152);
  LatLng? _currentPosition;
  late GoogleMapController _mapController;
  bool _hasListenerAttached = false;
  bool _hasRequestedPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocationSetup();
    }
  }

  Future<void> _initLocationSetup() async {
    // Check service
    bool serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled && !_hasRequestedPermission) {
      serviceEnabled = await _locationController.requestService();
      _hasRequestedPermission=true;
      if (!serviceEnabled) return;
    }

    // Permission flow
    PermissionStatus permissionGranted = await _locationController.hasPermission();

    if (permissionGranted == PermissionStatus.denied && !_hasRequestedPermission) {
      _hasRequestedPermission = true;
      permissionGranted = await _locationController.requestPermission();
    }

    // Only proceed if permission granted
    if (permissionGranted == PermissionStatus.granted) {
      if (!_hasListenerAttached) {
        _locationController.onLocationChanged.listen((LocationData locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            final newPosition = LatLng(locationData.latitude!, locationData.longitude!);
            if (mounted) {
              setState(() {
                _currentPosition = newPosition;
                print(_currentPosition);
              });
              // Optional: move camera
              _mapController.animateCamera(CameraUpdate.newLatLng(newPosition));
            }
          }
        });
        _hasListenerAttached = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mechanic Map'), centerTitle: true),
      body:_currentPosition==null? Center(
        child: Text("Loading"),
      ):GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _defaultLocation,
                zoom: 13,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId("current_location"),
                  position: _currentPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: "Your Location"),
                ),
                Marker(
                  markerId: const MarkerId("default_location"),
                  position: _defaultLocation,
                  infoWindow: const InfoWindow(title: "Default Location"),
                ),
              },
            ),
    );
  }
}
