import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EmergencyFormDialog extends StatefulWidget {
  const EmergencyFormDialog({super.key});

  @override
  State<EmergencyFormDialog> createState() => _EmergencyFormDialogState();
}

class _EmergencyFormDialogState extends State<EmergencyFormDialog> {
  final _vehicleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _capturedImage;

  String? _location;   // Human-readable address
  Position? _coords;   // Raw coordinates, for database (future)
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
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _location = 'Location denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _coords = pos;

      // Try reverse geocoding
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      } catch (_) {}

      final address = placemarks.isNotEmpty
          ? '${placemarks.first.street?.isNotEmpty == true ? placemarks.first.street! + ', ' : ''}'
          '${placemarks.first.locality?.isNotEmpty == true ? placemarks.first.locality! + ', ' : ''}'
          '${placemarks.first.country ?? ''}'
          : 'No address found';

      if (!mounted) return;
      setState(() => _location = address.trim().isEmpty ? "Unknown location" : address);
    } catch (e) {
      if (!mounted) return;
      setState(() => _location = 'Location error');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() => _capturedImage = File(pickedFile.path));
    }
  }

  Future<void> _handleSubmit() async {
    final vehicle = _vehicleController.text.trim();
    final desc = _descriptionController.text.trim();

    if (vehicle.isEmpty || desc.isEmpty || _capturedImage == null) {
      _showMessage('Please fill all fields and take a picture.');
      return;
    }
    // Commented out DB logic:
    /*
    final supabase = Supabase.instance.client;
    await supabase.from('emergencies').insert({
      'vehicle_model': vehicle,
      'description': desc,
      'location_address': _location,
      'location_lat': _coords?.latitude,
      'location_lng': _coords?.longitude,
      // (image upload logic goes here)
    });
    */
    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss the dialog
    _showMessage('Emergency request submitted successfully.');
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontFamily: AppFonts.primaryFont,
                  ),
                ),
                onPressed: _takePicture,
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
