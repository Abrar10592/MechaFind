import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mechfind/utils.dart';
import 'location_service.dart';
import 'widgets/emergency_button.dart';
import 'widgets/bottom_navbar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class UserHomePage extends StatefulWidget {
  final bool isGuest;
  const UserHomePage({super.key, this.isGuest = false});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? userName;
  String currentLocation = 'Getting location...';
  double? userLat;
  double? userLng;
  List<Map<String, dynamic>> nearbyMechanics = [];

  @override
  void initState() {
    super.initState();
    _checkLocationServiceAndLoad();
  }

  /// Check if device location service is enabled; if not, prompt user to enable it
  Future<void> _checkLocationServiceAndLoad() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Opens the native settings screen
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location services are required to use this app.')),
          );
        }
        return; // stop here if still not enabled
      }
    }

    // Now safe to proceed
    await fetchUserLocation();
    if (widget.isGuest) {
      await _insertGuestSession();
    } else {
      await _fetchUserName();
    }
    await _fetchMechanicsFromDB();
  }

  Future<void> _insertGuestSession() async {
    try {
      final supabase = Supabase.instance.client;
      final sessionInfo =
          'Guest session at ${DateTime.now().toIso8601String()}';
      await supabase.from('guests').insert({'session_info': sessionInfo});
    } catch (e) {
      print("❌ Guest insert error: $e");
    }
  }

  Future<void> _fetchUserName() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      setState(() {
        userName = data?['full_name'] ?? '';
      });
    } catch (e) {
      print("❌ Name fetch error: $e");
    }
  }

  Future<void> fetchUserLocation() async {
    final location = await LocationService.getCurrentLocation(context);
    if (location != null) {
      final parts = location.split(', ');
      userLat = double.tryParse(parts[0]);
      userLng = double.tryParse(parts[1]);
      final address = await getAddressFromLatLng(userLat!, userLng!);
      setState(() {
        currentLocation = address;
      });
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks.first;
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('⚠️ Reverse geocode error: $e');
      return 'Location not found';
    }
  }

  double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  Future<void> _fetchMechanicsFromDB() async {
    if (userLat == null || userLng == null) {
      print("⚠️ No user location yet");
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final mechanicData = await supabase.from('mechanics').select('''
            id,
            rating,
            location_x,
            location_y,
            users(full_name, image_url),
            mechanic_services(service_id, services(name))
            ''');

      List<Map<String, dynamic>> mechanicsList = [];
      for (final mech in mechanicData) {
        final mLat = mech['location_x'] is double
            ? mech['location_x']
            : double.tryParse(mech['location_x'].toString()) ?? 0.0;
        final mLng = mech['location_y'] is double
            ? mech['location_y']
            : double.tryParse(mech['location_y'].toString()) ?? 0.0;

        final distance = _calculateDistanceKm(userLat!, userLng!, mLat, mLng);
        if (distance <= 7.0) {
          final services = (mech['mechanic_services'] as List<dynamic>)
              .map((s) => s['services']?['name'] as String?)
              .whereType<String>()
              .toList();

          mechanicsList.add({
            'id': mech['id'],
            'name': mech['users']?['full_name'] ?? 'Unnamed',
            'image_url': mech['users']?['image_url'],
            'distance': '${distance.toStringAsFixed(1)} km',
            'rating': mech['rating'] ?? 0.0,
            'services': services,
          });
        }
      }
      setState(() {
        nearbyMechanics = mechanicsList;
      });
    } catch (e) {
      print("❌ Fetch mechanics error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingText =
    widget.isGuest ? "Welcome" : "Welcome ${userName ?? ''}";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          greetingText,
          style: AppTextStyles.heading.copyWith(color: Colors.white),
        ),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentLocation,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmergencyButton(),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Nearby Mechanics',
              style:
              AppTextStyles.heading.copyWith(fontSize: FontSizes.subHeading),
            ),
          ),
          const SizedBox(height: 10),
          if (nearbyMechanics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No mechanics found."),
            )
          else
            Column(
              children: nearbyMechanics.map((mech) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mech['image_url'] != null &&
                              mech['image_url'].toString().isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.network(
                              mech['image_url'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person,
                                      size: 40, color: Colors.white),
                                );
                              },
                            ),
                          )
                              : Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: const Icon(Icons.person,
                                size: 40, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mech['name'],
                                  style: AppTextStyles.heading.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Distance: ${mech['distance']}'),
                                Text('Rating: ${mech['rating']}'),
                                const SizedBox(height: 4),
                                Text(
                                    'Services: ${mech['services'].join(', ')}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            print("Request service from ${mech['name']}");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          child: const Text("Request Service"),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushNamed(context, '/messages');
              break;
            case 3:
              Navigator.pushNamed(context, '/history');
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }
}
