// location_service.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Get the current location and handle permission
  static Future<String?> getCurrentLocation(BuildContext context) async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationDialog(context, 'Please enable location services in your device settings to continue.');
        return null;
      }

      // Check location permissions.
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationDialog(context, 'Location access is required to find nearby mechanics.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationDialog(context, 'Please enable location permission in app settings to continue.');
        return null;
      }

      // If permission is granted, get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Unable to get your location. Please try again.'),
      );

      return '${position.latitude}, ${position.longitude}';
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('timeout') || e.toString().contains('Unable to get')) {
        errorMessage = 'Unable to get your location. Please check your GPS signal and try again.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network issue while getting location. Please check your internet connection.';
      } else {
        errorMessage = 'Unable to access location. Please ensure location services are enabled.';
      }
      
      _showLocationDialog(context, errorMessage);
      return null;
    }
  }

  // Show a dialog if location is not available
  static void _showLocationDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
