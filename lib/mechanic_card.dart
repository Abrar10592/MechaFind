import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';

class MechanicCard extends StatelessWidget {
  final Map mechanic;

  const MechanicCard({super.key, required this.mechanic});

  @override
  Widget build(BuildContext context) {
    final bool isOnline = mechanic['status'] == 'Online';
    final List services = mechanic['services'] ?? [];
    final String photoUrl = mechanic['photoUrl'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mechanic photo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: photoUrl.startsWith('http')
                  ? Image.network(photoUrl, width: 70, height: 70, fit: BoxFit.cover)
                  : Image.asset(photoUrl, width: 70, height: 70, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            // Main details and services
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mechanic['name'],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: AppFonts.primaryFont,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        mechanic['distance'],
                        style: AppTextStyles.label.copyWith(
                          fontFamily: AppFonts.secondaryFont,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${mechanic['rating']}',
                        style: AppTextStyles.label.copyWith(
                          fontFamily: AppFonts.secondaryFont,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Services (horizontal chips)
                  Wrap(
                    spacing: 6,
                    children: services.take(4).map<Widget>((service) {
                      return Chip(
                        label: Text(service,
                            style: AppTextStyles.label.copyWith(
                                color: AppColors.primary, fontSize: 11)),
                        backgroundColor: Colors.grey[200],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Online/offline status
            Container(
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : AppColors.textSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mechanic['status'],
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppFonts.secondaryFont,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
