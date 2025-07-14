import 'package:flutter/material.dart';
import 'selected_role.dart'; // Import the global variable

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Choose Your Role'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Text(
              'Select how you want to use MechFind',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 40),
            RoleCard(
              icon: Icons.directions_car,
              title: 'Vehicle Owner',
              description:
              'Get help when your vehicle breaks down. Connect with nearby mechanics instantly.',
              bulletPoints: [
                'Emergency assistance',
                'Find nearby mechanics',
                'Real-time tracking',
              ],
              onTap: () {
                selectedRole = 'user';
                Navigator.pushNamed(context, '/signup');
              },
            ),
            SizedBox(height: 20),
            RoleCard(
              icon: Icons.build,
              title: 'Mechanic / Workshop',
              description:
              'Provide roadside assistance and grow your business by helping drivers in need.',
              bulletPoints: [
                'Receive help requests',
                'Manage availability',
                'Build your reputation',
              ],
              onTap: () {
                selectedRole = 'mechanic';
                Navigator.pushNamed(context, '/signup');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bulletPoints;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.bulletPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 50, color: Theme.of(context).primaryColor),
              SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 10),
              ...bulletPoints.map((point) => Row(
                children: [
                  Text('• ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
