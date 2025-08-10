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
  bool _isPlaceNameLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
    _fetchPlaceName();
  }

  void _calculateDistance() {
    try {
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
    } catch (e) {
      // Distance calculation failed, distanceInKm remains null
      print('Error calculating distance: $e');
    }
  }

  Future<void> _fetchPlaceName() async {
    final lat = widget.request['lat'];
    final lng = widget.request['lng'];

    if (lat == null || lng == null) {
      setState(() {
        placeName = 'Location unavailable';
        _isPlaceNameLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ&types=place,locality,address&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Network timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          setState(() {
            placeName = features.first['place_name'] ?? 'Nearby location';
            _isPlaceNameLoading = false;
          });
        } else {
          setState(() {
            placeName = 'Nearby location';
            _isPlaceNameLoading = false;
          });
        }
      } else {
        setState(() {
          placeName = 'Nearby location';
          _isPlaceNameLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        placeName = 'Nearby location';
        _isPlaceNameLoading = false;
      });
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
                  backgroundImage: (request['image_url'] != null && 
                      request['image_url'].toString().isNotEmpty)
                      ? NetworkImage(request['image_url'].toString())
                      : const AssetImage('zob_assets/user_icon.png')
                          as ImageProvider,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['user_name']?.toString() ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request['vehicle']?.toString() ?? 'Unknown Vehicle',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceInKm != null)
                  Text(
                    '${distanceInKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            /// Issue Image (full width)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (request['image'] != null && 
                  request['image'].toString().isNotEmpty)
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
                  child: _isPlaceNameLoading
                      ? const Text(
                          'Loading location...',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        )
                      : Text(
                          placeName ?? 'Nearby location',
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
