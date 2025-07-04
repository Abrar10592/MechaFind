// location_service.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Get the current location and handle permission
  static Future<String?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog(context, 'Location services are disabled. Please enable GPS.');
      return null;
    }

    // Check location permissions.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog(context, 'Location permission is denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationDialog(context, 'Location permission is permanently denied. Please enable it from app settings.');
      return null;
    }

    // If permission is granted, get current position
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    return '${position.latitude}, ${position.longitude}';
  }

  // Show a dialog if location is not available
  static void _showLocationDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
