import 'dart:io';

import 'package:flutter/material.dart';

import 'package:geocoding/geocoding.dart';

import 'package:geolocator/geolocator.dart';

import 'package:image_picker/image_picker.dart';

import 'package:latlong2/latlong.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../active_emergency_route_page.dart'; // kept original import

import 'package:mechfind/utils.dart'; // Update import if needed

class EmergencyFormDialog extends StatefulWidget {
  const EmergencyFormDialog({super.key});

  @override
  State createState() => _EmergencyFormDialogState();
}

class _EmergencyFormDialogState extends State<EmergencyFormDialog> {
  final _vehicleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _capturedImage;
  String? _location;
  Position? _coords;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future _fetchLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print("Location permission before request: $permission");
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print("Location permission after request: $permission");
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() {
            _location = 'Location permission denied';
            _loading = false;
          });
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _coords = pos;
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        print("Placemarks obtained: $placemarks");
      } catch (e) {
        print("Reverse geocoding error: $e");
      }
      final address = placemarks.isNotEmpty
          ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}, ${placemarks.first.country ?? ''}'
          : 'No address found';
      setState(() {
        _location = address.trim().isEmpty ? "Unknown location" : address;
        _loading = false;
      });
    } catch (e) {
      print("Fetching location error: $e");
      setState(() {
        _location = 'Failed to get location';
        _loading = false;
      });
    }
  }

  Future _takePicture() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
      if (pickedFile != null) {
        setState(() {
          _capturedImage = File(pickedFile.path);
        });
        print("Picture taken: ${pickedFile.path}");
      }
    } catch (e) {
      print("Error taking picture: $e");
      _showMessage('Failed to take picture: $e');
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future _handleSubmit() async {
    final vehicle = _vehicleController.text.trim();
    final desc = _descriptionController.text.trim();

    if (vehicle.isEmpty || desc.isEmpty || _capturedImage == null) {
      _showMessage('Please fill all fields and take a photo.');
      return;
    }
    if (_coords == null) {
      _showMessage('Location not available.');
      return;
    }
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance;
      var user = supabase.client.auth.currentUser;
      print('Current user info: $user');

      String userId;
      if (user == null) {
        print("User is guest, inserting guest record.");
        final response = await supabase.client
            .from('guests')
            .insert({'session_info': 'Guest session at ${DateTime.now().toIso8601String()}'})
            .select()
            .single();

        if (response == null || response['id'] == null) {
          print("Failed to insert guest session");
          _showMessage("Failed to create guest session");
          setState(() => _loading = false);
          return;
        }
        userId = response['id'] as String;
        print("Guest id received: $userId");
      } else {
        userId = user.id;
      }

      const bucketName = 'request-photos';
      final fileExt = _capturedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final filePath = 'requests/$userId/$fileName';

      print("Uploading image to path: $filePath");

      final uploadedPath = await supabase.client.storage.from(bucketName).upload(filePath, File(_capturedImage!.path));
      print('Uploaded path from Supabase: $uploadedPath');

      String relativePath = uploadedPath;
      if (relativePath.startsWith('$bucketName/')) {
        relativePath = relativePath.substring(bucketName.length + 1);
        print('Adjusted relative path for signed URL: $relativePath');
      }

      final imageUrl = await supabase.client.storage.from(bucketName).createSignedUrl(relativePath, 86400);
      print('Signed URL generated: $imageUrl');

      final requestResponse = await supabase.client
          .from('requests')
          .insert({
        'user_id': userId,
        'mechanic_id': null,
        'status': 'pending',
        'vehicle': vehicle,
        'description': desc,
        'image': imageUrl,
        'lat': _coords!.latitude.toString(),
        'lng': _coords!.longitude.toString(),
        'mech_lat': null,
        'mech_lng': null,
        'request_type': 'emergency',
      })
          .select()
          .single();

      print("Request insert response: $requestResponse");

      if (requestResponse == null) {
        _showMessage('Failed to submit request. Please try again.');
        setState(() => _loading = false);
        return;
      }

      final requestId = requestResponse['id'] as String;
      final lat = double.tryParse(requestResponse['lat'] ?? '') ?? _coords!.latitude;
      final lng = double.tryParse(requestResponse['lng'] ?? '') ?? _coords!.longitude;

      print("Navigating with requestId: $requestId, lat: $lat, lng: $lng");

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ActiveEmergencyRoutePage(
            requestId: requestId,
            userLocation: LatLng(lat, lng),
          )));
    } catch (e, stackTrace) {
      print('Exception during submission: $e\nStack trace:\n$stackTrace');
      if (e is PostgrestException) {
        print('PostgREST specific message: ${e.message}');
      }
      _showMessage('Error submitting request: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Request Emergency Help',
              style: AppTextStyles.heading.copyWith(
                  color: Colors.white,
                  fontFamily: AppFonts.primaryFont,
                  fontSize: FontSizes.subHeading + 2),
            ),
            const SizedBox(height: 6),
            Text(
              _loading ? "Getting location..." : (_location ?? "Location unavailable"),
              style: AppTextStyles.label.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _vehicleController,
              style: AppTextStyles.body.copyWith(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.directions_car, color: Colors.white70),
                hintText: "Vehicle Model",
                hintStyle: AppTextStyles.label.copyWith(color: Colors.white60),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              style: AppTextStyles.body.copyWith(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.report_problem, color: Colors.white70),
                hintText: "Describe your problem",
                hintStyle: AppTextStyles.label.copyWith(color: Colors.white60),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.accent.withOpacity(0.7)),
                backgroundColor: AppColors.primary.withOpacity(0.15),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: Text(
                _capturedImage == null ? "Take Photo" : "Retake Photo",
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              onPressed: _loading ? null : _takePicture,
            ),
            if (_capturedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_capturedImage!, height: 110),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _handleSubmit,
                child: Text(
                  _loading ? "Submitting..." : "Submit",
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: FontSizes.subHeading),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
