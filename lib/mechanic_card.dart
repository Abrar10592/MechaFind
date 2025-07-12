import 'package:flutter/material.dart';

class MechanicCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;

  const MechanicCard({super.key, required this.mechanic});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(mechanic['name']),
        subtitle: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey),
            SizedBox(width: 4),
            Text(mechanic['distance']),
            SizedBox(width: 10),
            Icon(Icons.star, size: 16, color: Colors.amber),
            SizedBox(width: 4),
            Text('${mechanic['rating']}'),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: mechanic['status'] == 'Online' ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mechanic['status'],
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
