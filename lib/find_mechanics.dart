import 'package:flutter/material.dart';
import 'detailed_mechanic_card.dart';
import 'widgets/bottom_navbar.dart';

class FindMechanicsPage extends StatelessWidget {
  const FindMechanicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mechanics = [
      {
        'name': 'AutoCare Plus',
        'address': '123 Main St, Downtown',
        'distance': '0.8 km',
        'rating': 4.9,
        'reviews': 156,
        'response': '5 min',
        'services': ['Engine Repair', 'Brake Service', 'Oil Change'],
        'online': true,
      },
      {
        'name': 'QuickFix Motors',
        'address': '456 Oak Ave, Midtown',
        'distance': '1.2 km',
        'rating': 4.7,
        'reviews': 89,
        'response': '8 min',
        'services': ['Towing', 'Jump Start', 'Tire Change'],
        'online': true,
      },
      {
        'name': 'Elite Auto Workshop',
        'address': '',
        'distance': '',
        'rating': null,
        'reviews': null,
        'response': '',
        'services': [],
        'online': false,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Mechanics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or service',
                suffixIcon: Icon(Icons.filter_list),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('${mechanics.length} mechanics found near you',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            ...mechanics.map((mech) => DetailedMechanicCard(mechanic: mech)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Find Mechanics tab index
        onTap: (index) {
          if (index == 1) return; // Already on Find Mechanics
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/userHome');
              break;
            case 2:
              // Messages - can be implemented later
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Messages feature coming soon'),
              ));
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
