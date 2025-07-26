import 'package:flutter/material.dart';
import 'detailed_mechanic_card.dart';

class MechanicInfoWrapper extends StatelessWidget {
  final Map<String, dynamic> mechanicRaw;

  const MechanicInfoWrapper({super.key, required this.mechanicRaw});

  @override
  Widget build(BuildContext context) {
    final adaptedMechanic = <String, dynamic>{
      'name': mechanicRaw['name'] ?? 'Unknown',
      'address': mechanicRaw['address'] ?? '',
      'online': mechanicRaw['online'] ??
          (mechanicRaw['status']?.toString().toLowerCase() == 'online'),
      'distance': mechanicRaw['distance'] ?? '',
      'rating': mechanicRaw['rating'] ?? 0.0,
      'reviews': mechanicRaw['reviews'] ?? 0,
      'response': mechanicRaw['response'] ?? mechanicRaw['responseTime'] ?? '',
      'photoUrl': mechanicRaw['photoUrl'] ?? '',
      'services': mechanicRaw['services'] ?? <String>[],
    };
    return DetailedMechanicCard(mechanic: adaptedMechanic);
  }
}
