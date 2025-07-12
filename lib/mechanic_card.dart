import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';

class MechanicCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;

  const MechanicCard({super.key, required this.mechanic});

  @override
  Widget build(BuildContext context) {
    final bool isOnline = mechanic['status'] == 'Online';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        title: Text(
          mechanic['name'],
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        subtitle: Row(
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
        trailing: Container(
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
      ),
    );
  }
}
