import 'dart:io';

import 'package:flutter/material.dart';

import 'package:geocoding/geocoding.dart';

import 'package:geolocator/geolocator.dart';

import 'package:image_picker/image_picker.dart';

import 'package:latlong2/latlong.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_map/flutter_map.dart';

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
  bool _useCurrentLocation = true;
  LatLng? _selectedMapLocation;

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
      await _updateLocationDisplay(pos.latitude, pos.longitude);
    } catch (e) {
      print("Fetching location error: $e");
      setState(() {
        _location = 'Failed to get location';
        _loading = false;
      });
    }
  }

  Future _updateLocationDisplay(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      print("Placemarks obtained: $placemarks");
      final address = placemarks.isNotEmpty
          ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}, ${placemarks.first.country ?? ''}'
          : 'No address found';
      setState(() {
        _location = address.trim().isEmpty ? "Unknown location" : address;
        _loading = false;
      });
    } catch (e) {
      print("Reverse geocoding error: $e");
      setState(() {
        _location = 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
        _loading = false;
      });
    }
  }

  Future _openMapPicker() async {
    Position? currentPos;
    try {
      currentPos = await Geolocator.getCurrentPosition();
    } catch (e) {
      print("Error getting current position for map: $e");
      // Use a default location if current position is not available
      currentPos = Position(
        latitude: 23.8103,
        longitude: 90.4125,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    final selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => _MapLocationPicker(
          initialLocation: LatLng(currentPos!.latitude, currentPos.longitude),
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        _selectedMapLocation = selectedLocation;
        _useCurrentLocation = false;
        _loading = true;
      });
      await _updateLocationDisplay(selectedLocation.latitude, selectedLocation.longitude);
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

    // Determine which location to use
    double lat, lng;
    if (_useCurrentLocation) {
      if (_coords == null) {
        _showMessage('Current location not available.');
        return;
      }
      lat = _coords!.latitude;
      lng = _coords!.longitude;
    } else {
      if (_selectedMapLocation == null) {
        _showMessage('Please select a location on the map.');
        return;
      }
      lat = _selectedMapLocation!.latitude;
      lng = _selectedMapLocation!.longitude;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance;
      var user = supabase.client.auth.currentUser;
      print('🔍 Current user info: $user');
      print('🔍 User ID: ${user?.id}');
      print('🔍 User authenticated: ${user != null}');

      String? userId;
      String? guestId;
      String folderUserId;
      
      if (user == null) {
        print("User is guest, inserting guest record.");
        final response = await supabase.client
            .from('guests')
            .insert({'session_info': 'Guest session at ${DateTime.now().toIso8601String()}'})
            .select()
            .single();

        if (response['id'] == null) {
          print("Failed to insert guest session");
          _showMessage("Failed to create guest session");
          setState(() => _loading = false);
          return;
        }
        guestId = response['id'] as String;
        folderUserId = guestId;
        print("Guest id received: $guestId");
      } else {
        userId = user.id;
        folderUserId = userId;
        print("🔍 Logged in user id: $userId");
        print("🔍 Auth.uid() should match user_id for RLS: auth.uid()=${user.id} == user_id=$userId");
      }

      const bucketName = 'request-photos';
      final fileExt = _capturedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final filePath = 'requests/$folderUserId/$fileName';

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

      // Prepare the request data conditionally
      Map<String, dynamic> requestData = {
        'mechanic_id': null,
        'status': 'pending',
        'vehicle': vehicle,
        'description': desc,
        'image': imageUrl,
        'lat': lat.toString(),
        'lng': lng.toString(),
        'mech_lat': null,
        'mech_lng': null,
        'request_type': 'emergency',
      };

      // Add either user_id or guest_id based on user type (clean separation)
      if (user == null) {
        requestData['guest_id'] = guestId;
        print("🔍 Inserting request for guest with guest_id: $guestId");
        print("🔍 RLS should check: EXISTS(SELECT 1 FROM guests WHERE guests.id = '$guestId')");
      } else {
        requestData['user_id'] = userId;
        print("🔍 Inserting request for authenticated user with user_id: $userId");
        print("🔍 RLS should check: auth.uid() = '$userId'");
        print("🔍 Current auth.uid(): ${user.id}");
      }

      print("🔍 Final request data being inserted: $requestData");

      final requestResponse = await supabase.client
          .from('requests')
          .insert(requestData)
          .select()
          .single();

      print("✅ Request insert successful: $requestResponse");

      final requestId = requestResponse['id'] as String;
      final responseLat = double.tryParse(requestResponse['lat'] ?? '') ?? lat;
      final responseLng = double.tryParse(requestResponse['lng'] ?? '') ?? lng;

      print("Navigating with requestId: $requestId, lat: $responseLat, lng: $responseLng");

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ActiveEmergencyRoutePage(
            requestId: requestId,
            userLocation: LatLng(responseLat, responseLng),
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
            Row(
              children: [
                Icon(
                  _useCurrentLocation ? Icons.location_on : Icons.map,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _loading ? "Getting location..." : (_location ?? "Location unavailable"),
                    style: AppTextStyles.label.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location selection buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _useCurrentLocation 
                          ? AppColors.accent 
                          : Colors.white30,
                        width: 2,
                      ),
                      backgroundColor: _useCurrentLocation 
                        ? AppColors.accent.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      Icons.my_location,
                      color: _useCurrentLocation ? AppColors.accent : Colors.white70,
                    ),
                    label: Text(
                      "Current",
                      style: AppTextStyles.body.copyWith(
                        color: _useCurrentLocation ? AppColors.accent : Colors.white70,
                        fontWeight: _useCurrentLocation ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onPressed: _loading ? null : () {
                      setState(() {
                        _useCurrentLocation = true;
                        _selectedMapLocation = null;
                      });
                      _fetchLocation();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: !_useCurrentLocation 
                          ? AppColors.accent 
                          : Colors.white30,
                        width: 2,
                      ),
                      backgroundColor: !_useCurrentLocation 
                        ? AppColors.accent.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      Icons.map,
                      color: !_useCurrentLocation ? AppColors.accent : Colors.white70,
                    ),
                    label: Text(
                      "Pick on Map",
                      style: AppTextStyles.body.copyWith(
                        color: !_useCurrentLocation ? AppColors.accent : Colors.white70,
                        fontWeight: !_useCurrentLocation ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onPressed: _loading ? null : _openMapPicker,
                  ),
                ),
              ],
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

class _MapLocationPicker extends StatefulWidget {
  final LatLng initialLocation;

  const _MapLocationPicker({
    required this.initialLocation,
  });

  @override
  State<_MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<_MapLocationPicker> {
  LatLng? _selectedLocation;
  String _selectedAddress = "Loading...";

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateAddress(widget.initialLocation);
  }

  Future<void> _updateAddress(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
              .replaceAll(RegExp(r'^,\s*'), '') // Remove leading comma
              .replaceAll(RegExp(r',\s*$'), ''); // Remove trailing comma
        });
      } else {
        setState(() {
          _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Pick Location',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.gradientStart,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selectedLocation != null 
              ? () => Navigator.pop(context, _selectedLocation)
              : null,
            child: Text(
              'Confirm',
              style: AppTextStyles.body.copyWith(
                color: _selectedLocation != null ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Address display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Location:',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                  _updateAddress(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ",
                  additionalOptions: {
                    'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ',
                    'id': 'mapbox.mapbox-traffic-v1',
                  },
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.danger,
                                AppColors.danger.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.danger.withOpacity(0.6),
                                spreadRadius: 4,
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.background,
            child: Text(
              'Tap on the map to select your emergency location',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
