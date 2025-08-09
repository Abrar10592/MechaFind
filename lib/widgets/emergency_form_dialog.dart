import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../active_emergency_route_page.dart';
import 'package:mechfind/utils.dart'; // Update this import if needed

class EmergencyFormDialog extends StatefulWidget {
  const EmergencyFormDialog({super.key});

  @override
  State<EmergencyFormDialog> createState() => _EmergencyFormDialogState();
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

  Future<void> _fetchLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
      } catch (_) {}

      final address = placemarks.isNotEmpty
          ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}, ${placemarks.first.country ?? ''}'
          : 'No address found';

      setState(() {
        _location = address.trim().isEmpty ? "Unknown location" : address;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _location = 'Failed to get location';
        _loading = false;
      });
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
      if (pickedFile != null) {
        setState(() => _capturedImage = File(pickedFile.path));
      }
    } catch (e) {
      _showMessage('Failed to take picture: $e');
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _handleSubmit() async {
    final vehicle = _vehicleController.text.trim();
    final desc = _descriptionController.text.trim();

    if (vehicle.isEmpty || desc.isEmpty || _capturedImage == null) {
      _showMessage('Please fill all fields and take a picture.');
      return;
    }

    if (_coords == null) {
      _showMessage("Location not available.");
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      print('🔐 Current user ID: ${user?.id}');
      if (user == null) {
        _showMessage('You must be logged in to submit a request.');
        setState(() => _loading = false);
        return;
      }

      final bucketName = 'request-photos'; // Your private bucket name
      final fileExt = _capturedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'requests/${user.id}/$fileName'; // <--- RELATIVE to bucket

      print('🛣️ Intended file path: $filePath');

      String uploadedPath = '';
      try {
        uploadedPath = await supabase.storage.from(bucketName).upload(filePath, _capturedImage!);
        print('📦 Uploaded path from Supabase: $uploadedPath');
      } catch (e) {
        print('❗ Upload error: $e');
        _showMessage('Image upload failed: $e');
        setState(() => _loading = false);
        return;
      }

      // uploadedPath should be 'requests/userid/filename.jpg'.
      // If it starts with 'request-photos/', strip it:
      String relativePath = uploadedPath;
      if (relativePath.startsWith('$bucketName/')) {
        relativePath = relativePath.replaceFirst('$bucketName/', '');
        print('✂️ Adjusted relative path for signed URL: $relativePath');
      }

      String imageUrl = '';
      try {
        imageUrl = await supabase.storage.from(bucketName).createSignedUrl(relativePath, 86400);
        print('🔗 Obtained signed URL: $imageUrl');
      } catch (e) {
        print('❗ Signed URL error: $e');
        _showMessage('Failed to get signed URL: $e');
        setState(() => _loading = false);
        return;
      }

      // Insert emergency request into 'requests' table
      final response = await supabase.from('requests').insert({
        'user_id': user.id,
        'mechanic_id': null,
        'status': 'pending',
        'vehicle': vehicle,
        'description': desc,
        'image': imageUrl,
        'lat': _coords!.latitude.toString(),
        'lng': _coords!.longitude.toString(),
        'mech_lat': null,
        'mech_lng': null,
      }).select('id, lat, lng');

      if (response.isEmpty) {
        _showMessage('Failed to submit request. Try again.');
        setState(() => _loading = false);
        return;
      }

      final Map<String, dynamic> requestRow = response.first;
      final String requestId = requestRow['id'];
      final double latitude = double.tryParse(requestRow['lat']) ?? _coords!.latitude;
      final double longitude = double.tryParse(requestRow['lng']) ?? _coords!.longitude;

      print('✅ Request inserted with ID: $requestId');

      // Navigate to the Active Emergency Route Page
      if (!mounted) return;
      Navigator.of(context).pop(); // Close this dialog
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveEmergencyRoutePage(
            requestId: requestId,
            userLocation: LatLng(latitude, longitude),
          ),
        ),
      );
    } catch (e) {
      print('❗ Unexpected error: $e');
      _showMessage('Unexpected error occurred: $e');
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
                fontSize: FontSizes.subHeading + 2,
              ),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
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
                  _capturedImage == null ? "Take a Photo" : "Retake Photo",
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
                onPressed: _loading ? null : _takePicture,
              ),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: FontSizes.subHeading,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
