import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/mechanic/mechanic.dart';
import 'location_service.dart';
import 'mechanic_card.dart';
import 'widgets/emergency_button.dart';
import 'widgets/bottom_navbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({Key? key}) : super(key: key);

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String userName = 'Bobby'; // Will be replaced with actual DB data
  String currentLocation = 'Getting location...';
  bool locationPermissionGranted = false;

  List<Map<String, dynamic>> nearbyMechanics = [
    {'name': "Mike's Auto Repair", 'distance': '0.5 km', 'rating': 4.8, 'status': 'Online'},
    {'name': "QuickFix Motors", 'distance': '1.2 km', 'rating': 4.6, 'status': 'Online'},
    {'name': "City Garage", 'distance': '2.1 km', 'rating': 4.9, 'status': 'Offline'},
  ];

  @override
  void initState() {
    super.initState();
    fetchUserLocation();
  }

  Future<void> fetchUserLocation() async {
    final location = await LocationService.getCurrentLocation(context);
    if (location != null) {
      final parts = location.split(', ');
      final lat = double.parse(parts[0]);
      final lng = double.parse(parts[1]);

      final address = await getAddressFromLatLng(lat, lng);
      setState(() {
        currentLocation = address;
        locationPermissionGranted = true;
      });
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('Error in reverse geocoding: $e');
      return 'Location not found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Good morning, $userName!',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  currentLocation,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: AppFonts.secondaryFont,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const EmergencyButton(),
            const SizedBox(height: 30),

            Text(
              'Nearby Mechanics',
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.subHeading,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            const SizedBox(height: 10),

            Column(
              children: nearbyMechanics.map((mechanic) {
                return MechanicCard(mechanic: mechanic);
              }).toList(),
            ),
            const SizedBox(height: 30),

            Text(
              'Recent Activity',
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.subHeading,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'No recent activity',
                      style: AppTextStyles.body.copyWith(
                        fontFamily: AppFonts.secondaryFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Mechanic()));
              },
              child: Text(
                "Test Mechanic Page",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          switch (index) {
            case 1:
              Navigator.pushReplacementNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/messages');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/history');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }
}
