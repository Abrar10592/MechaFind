import 'package:flutter/material.dart';
import 'screens/profile/mechanic_profile_page.dart';
import 'services/mechanic_service.dart';

class DetailedMechanicCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;

  const DetailedMechanicCard({super.key, required this.mechanic});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + Status Dot
            Row(
              children: [
                Expanded(
                  child: Text(
                    mechanic['name'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.circle, size: 12, color: mechanic['online'] ? Colors.green : Colors.grey),
              ],
            ),
            const SizedBox(height: 4),

            // Address
            if (mechanic['address'] != '') Text(mechanic['address']),

            const SizedBox(height: 6),

            // Distance, Rating, Response Time
            Row(
              children: [
                Text(mechanic['distance'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                if (mechanic['rating'] != null)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text('${mechanic['rating']} (${mechanic['reviews']})'),
                    ],
                  ),
                const Spacer(),
                Text('Response: ${mechanic['response']}'),
              ],
            ),

            const SizedBox(height: 10),

            // Services
            if (mechanic['services'].isNotEmpty)
              Wrap(
                spacing: 8,
                children: List<Widget>.from(
                  mechanic['services'].map((service) => Chip(label: Text(service))),
                ),
              ),

            const SizedBox(height: 10),

            // Call + Message Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Call functionality
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Message functionality
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to profile
                      final mechanicModel = MechanicService.convertToMechanic(mechanic);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MechanicProfilePage(mechanic: mechanicModel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
