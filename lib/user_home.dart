import 'package:flutter/material.dart';
import 'location_service.dart';
import 'mechanic_card.dart';
import 'widgets/emergency_button.dart';
import 'widgets/bottom_navbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import geocoding

class UserHomePage extends StatefulWidget {
  const UserHomePage({Key? key}) : super(key: key);

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String userName = 'Bobby'; // This will come from DB later
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

      // Convert to readable address
      final address = await getAddressFromLatLng(lat, lng);

      setState(() {
        currentLocation = address;
        locationPermissionGranted = true;
      });
    }
  }

  // Function to convert coordinates to address
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
        title: Text('Good morning, $userName!'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[700]),
                SizedBox(width: 8),
                Text(currentLocation, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              ],
            ),
            SizedBox(height: 20),
            EmergencyButton(),
            SizedBox(height: 30),
            Text('Nearby Mechanics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Column(
              children: nearbyMechanics.map((mechanic) {
                return MechanicCard(mechanic: mechanic);
              }).toList(),
            ),
            SizedBox(height: 30),
            Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 10),
                    Text('No recent activity'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0, // Home tab index
        onTap: (index) {
          if (index == 0) return; // Already on Home
          switch (index) {
            case 1:
              Navigator.pushReplacementNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/messages'); // add if exists
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/history'); // add if exists
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile'); // add if exists
              break;
          }
        },
      ),
    );
  }
}
