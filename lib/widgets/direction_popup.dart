import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionPopup extends StatefulWidget {
  final LatLng? mechanicLocation;
  final LatLng requestLocation;
  final String phone;

  const DirectionPopup({
    super.key,
    required this.mechanicLocation,
    required this.requestLocation,
    required this.phone,
  });

  @override
  State<DirectionPopup> createState() => _DirectionPopupState();
}

class _DirectionPopupState extends State<DirectionPopup> {
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _getRoute();
  }

  Future<void> _getRoute() async {
    if (widget.mechanicLocation == null) return;

    // Replace with your actual Google Directions API key
    const String googleAPIKey = 'AIzaSyA-Ga_XiPM-pKWGfZqYYfiWN3WDbpvRrQE';

    
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(
          widget.mechanicLocation!.latitude,
          widget.mechanicLocation!.longitude,
        ),
        destination: PointLatLng(
          widget.requestLocation.latitude,
          widget.requestLocation.longitude,
        ),
        mode: TravelMode.driving,
      ),
      googleApiKey: googleAPIKey,
    );

    if (result.points.isNotEmpty) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.blue,
            width: 5,
            points: result.points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
          ),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "Directions",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.mechanicLocation ?? widget.requestLocation,
                zoom: 13,
              ),
              markers: {
                if (widget.mechanicLocation != null)
                  Marker(
                    markerId: const MarkerId('mech'),
                    position: widget.mechanicLocation!,
                    infoWindow: const InfoWindow(title: 'Your Location'),
                  ),
                Marker(
                  markerId: const MarkerId('req'),
                  position: widget.requestLocation,
                  infoWindow: const InfoWindow(title: 'Request Location'),
                ),
              },
              polylines: _polylines,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('tel:${widget.phone}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text("Call Requestee"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}