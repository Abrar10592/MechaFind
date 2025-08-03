import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

class SosCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final LatLng? current_location;
  final VoidCallback? onIgnore;
  final VoidCallback? onAccept;

  const SosCard({
    super.key,
    required this.request,
    required this.current_location,
    this.onIgnore,
    this.onAccept,
  });

  @override
  State<SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<SosCard> {
  double? distanceInKm;
  String? placeName;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
    _fetchPlaceName();
  }

  void _calculateDistance() {
    if (widget.current_location != null &&
        widget.request['lat'] != null &&
        widget.request['lng'] != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        widget.current_location!.latitude,
        widget.current_location!.longitude,
        widget.request['lat'],
        widget.request['lng'],
      );
      setState(() {
        distanceInKm = distanceInMeters / 1000;
      });
    }
  }

  Future<void> _fetchPlaceName() async {
    final lat = widget.request['lat'];
    final lng = widget.request['lng'];

    if (lat != null && lng != null) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
          '?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ&types=place,locality,address&limit=1',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            setState(() {
              placeName = features.first['place_name'] ?? 'Unknown location';
            });
          } else {
            placeName = 'Unknown location';
          }
        } else {
          placeName = 'Unknown location';
        }
      } catch (_) {
        placeName = 'Unknown location';
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header: User info
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: request['image'] != null
                      ? NetworkImage(request['image_url']?.toString() ?? '')
                      : const AssetImage('assets/images/default_user.png')
                          as ImageProvider,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['user_name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      request['vehicle']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (distanceInKm != null)
                  Text(
                    '${distanceInKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            /// Issue Image (full width)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: request['image'] != null
                  ? Image.network(
                      request['image'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(height: 180, color: Colors.grey[300]),
                    )
                  : Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported,
                          size: 60, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 14),

            /// Description
            Text(
              'issue_description'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              request['description']?.toString() ?? 'No description',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),

            /// Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    placeName ?? 'Loading location...',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            /// Phone
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(
                    request['phone']?.toString() ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            /// Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onIgnore,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('ignore'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey[700],
                      side: BorderSide(color: Colors.blueGrey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('accept'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
}
