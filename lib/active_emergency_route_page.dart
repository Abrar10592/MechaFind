import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ActiveEmergencyRoutePage extends StatelessWidget {
  final LatLng userLocation;
  final Map mechanic;

  const ActiveEmergencyRoutePage({
    super.key,
    required this.userLocation,
    required this.mechanic,
  });

  @override
  Widget build(BuildContext context) {
    final mechanicLocation = LatLng(23.7900, 90.4050); // Demo mechanic

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Mechanic Connected'),
      ),
      body: Column(
        children: [
          // SHOWN MAP - takes reasonable height
          SizedBox(
            height: 260,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (userLocation.latitude + mechanicLocation.latitude) / 2,
                  (userLocation.longitude + mechanicLocation.longitude) / 2,
                ),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [userLocation, mechanicLocation],
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 28),
                    ),
                    Marker(
                      point: mechanicLocation,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.build, color: Colors.green, size: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // SMALL, HORIZONTAL MECHANIC CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mechanic image (optional)
                CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage(mechanic['photoUrl'] ?? ''),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 12),
                // Basic mechanic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mechanic['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 15),
                          Text(" ${mechanic['rating'] ?? ''}"),
                          const SizedBox(width: 12),
                          Text(mechanic['distance'] ?? '', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${mechanic['status'] ?? ''}', // Online as plain text
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Services shown as chips, horizontally scrollable if many
                if (mechanic['services'] != null)
                  SizedBox(
                    width: 80,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List<Widget>.from(
                          (mechanic['services'] as List)
                              .map((service) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Chip(
                              label: Text(service, style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.blue[50],
                            ),
                          )),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}