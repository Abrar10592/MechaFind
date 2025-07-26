import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class Sos_Card extends StatelessWidget {
  final Map<String, dynamic> request;
  final LatLng? current_location;
  final VoidCallback? onIgnore;
  final VoidCallback? onAccept;

  const Sos_Card({
    super.key,
    required this.request,
    required this.current_location,
    this.onIgnore,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    double? distanceInKm;

    if (current_location != null &&
        request['lat'] != null &&
        request['lng'] != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        current_location!.latitude,
        current_location!.longitude,
        request['lat'],
        request['lng'],
      );
      distanceInKm = distanceInMeters / 1000;
    }

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(request['photo_url']),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      request['car_model'] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                if (request['is_urgent'] == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'urgent'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Issue image and description
            Row(
              children: [
                Image.network(
                  request['profile_url'],
                  height: 80,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'issue_description'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(request['issue_description'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                Text(request['location'] ?? ''),
                const Spacer(),
                if (distanceInKm != null)
                  Text(
                    '${distanceInKm.toStringAsFixed(2)} ${'km_away'.tr()}',
                    style: const TextStyle(color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Phone
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(request['phone'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onIgnore,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('ignore'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                          const Color.fromARGB(255, 85, 119, 136),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('accept'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
