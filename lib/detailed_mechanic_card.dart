import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/profile/mechanic_profile_page.dart';
import 'screens/chat/chat_screen.dart';
import 'services/mechanic_service.dart';
import 'services/find_mechanic_service.dart';
import 'utils/page_transitions.dart';

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
            // Header with Avatar, Name + Status Dot
            Row(
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: mechanic['image_url'] != null && mechanic['image_url'].toString().isNotEmpty
                      ? NetworkImage(mechanic['image_url'])
                      : null,
                  child: mechanic['image_url'] == null || mechanic['image_url'].toString().isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mechanic['name'] ?? 'Unknown Mechanic',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (mechanic['phone'] != null && mechanic['phone'].toString().isNotEmpty)
                        Text(
                          mechanic['phone'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.circle,
                  size: 12,
                  color: (mechanic['online'] ?? false) ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Address
            if (mechanic['address'] != null && mechanic['address'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mechanic['address'],
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),

            // Distance, Rating, Response Time
            Row(
              children: [
                if (mechanic['distance'] != null && mechanic['distance'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mechanic['distance'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (mechanic['rating'] != null && mechanic['rating'] > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '${mechanic['rating'].toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (mechanic['reviews'] != null && mechanic['reviews'] > 0)
                        Text(
                          ' (${mechanic['reviews']})',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                const Spacer(),
                if (mechanic['response'] != null && mechanic['response'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Response: ${mechanic['response']}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Services
            if (mechanic['services'] != null && (mechanic['services'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: List<Widget>.from(
                    (mechanic['services'] as List).map(
                      (service) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          service.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Call + Message + Profile Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(context, mechanic['phone']),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text(
                      'Call',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(context, mechanic),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text(
                      'Chat',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openProfile(context, mechanic),
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text(
                      'Profile',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  /// Make phone call to mechanic
  void _makePhoneCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw Exception('Could not launch phone dialer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Open chat with mechanic
  void _openChat(BuildContext context, Map<String, dynamic> mechanic) {
    final mechanicId = mechanic['id'];
    if (mechanicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start chat: Mechanic ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to chat screen with modal transition
    NavigationHelper.modalToPage(
      context,
      ChatScreen(
        mechanicId: mechanicId.toString(),
        mechanicName: mechanic['name'] ?? 'Mechanic',
        mechanicImageUrl: mechanic['image_url'],
      ),
    );
  }

  /// Open mechanic profile
  void _openProfile(BuildContext context, Map<String, dynamic> mechanic) async {
    final mechanicId = mechanic['id'];
    if (mechanicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open profile: Mechanic ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch complete mechanic details
      final mechanicDetails = await FindMechanicService.getMechanicById(mechanicId.toString());
      
      // Close loading indicator
      Navigator.of(context).pop();

      if (mechanicDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load mechanic profile'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convert to Mechanic model for profile page
      final mechanicModel = MechanicService.convertToMechanic(mechanicDetails);
      
      // Navigate to profile with hero transition
      NavigationHelper.heroToPage(
        context,
        MechanicProfilePage(mechanic: mechanicModel),
      );
    } catch (e) {
      // Close loading indicator if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
