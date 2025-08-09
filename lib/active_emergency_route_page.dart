import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveEmergencyRoutePage extends StatefulWidget {
  final String requestId;
  final LatLng userLocation;

  const ActiveEmergencyRoutePage({
    Key? key,
    required this.requestId,
    required this.userLocation,
  }) : super(key: key);

  @override
  State<ActiveEmergencyRoutePage> createState() => _ActiveEmergencyRoutePageState();
}

class _ActiveEmergencyRoutePageState extends State<ActiveEmergencyRoutePage> {
  late Stream<Map<String, dynamic>?> _requestStream;
  Map<String, dynamic>? _mechanicProfile;

  @override
  void initState() {
    super.initState();
    // Listen to updates on the specific request row ("status","mechanic_id")
    _requestStream = Supabase.instance.client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.requestId)
        .limit(1)
        .map((events) => events.isNotEmpty ? events.first : null);
  }

  Future<Map<String, dynamic>?> _fetchMechanicProfile(String mechanicId) async {
    // Fetch mechanic info from DB (for demo: name, rating, photoURL, etc)
    final res = await Supabase.instance.client
        .from('mechanics')
        .select('name, rating, image_url, lat, lng, phone, expertise')
        .eq('id', mechanicId)
        .maybeSingle();
    return res;
  }

  Widget _buildWaitingUI() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          width: double.infinity,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text(
          "Searching for mechanics nearby...",
          style: TextStyle(fontSize: 17, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        const Text("Mechanics are connecting...", style: TextStyle(fontSize: 15, color: Colors.black54)),
      ],
    );
  }

  Widget _buildConnectedUI(Map<String, dynamic> request, Map<String, dynamic> mechanic) {
    // show both user & mechanic on map, draw route, show mechanic card
    final LatLng? mechLocation = (mechanic['lat'] != null && mechanic['lng'] != null)
        ? LatLng(double.tryParse(mechanic['lat'].toString()) ?? 0, double.tryParse(mechanic['lng'].toString()) ?? 0)
        : null;

    return Column(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: mechLocation != null
                  ? LatLng(
                  (widget.userLocation.latitude + mechLocation.latitude) / 2,
                  (widget.userLocation.longitude + mechLocation.longitude) / 2)
                  : widget.userLocation,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (mechLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [widget.userLocation, mechLocation],
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation,
                    width: 34,
                    height: 34,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  if (mechLocation != null)
                    Marker(
                      point: mechLocation,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.build, color: Colors.green, size: 28),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // MECHANIC INFO CARD WITH BUTTONS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: (mechanic['image_url'] != null && mechanic['image_url'].toString().isNotEmpty)
                        ? NetworkImage(mechanic['image_url'])
                        : null,
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mechanic['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(" ${mechanic['rating'] ?? ''}", style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Status: Online', // option: mechanic status?
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: -4,
                          children: (mechanic['expertise'] as List<dynamic>? ?? [])
                              .map((service) => Chip(
                            label: Text(service.toString(), style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.blue[50],
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (mechanic['phone'] == null) return;
                      showDialog(
                        context: context,
                        builder: (_) => CallMechanicDialog(
                          mechanicName: mechanic['name'] ?? 'Mechanic',
                          phoneNumber: mechanic['phone'] ?? '',
                        ),
                      );
                    },
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[500],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("${mechanic['name'] ?? 'Mechanic'}'s Profile"),
                          content: const Text('Profile details and reviews coming soon...'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 19),
                    label: const Text("Profile"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      minimumSize: const Size(100, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Colors.black12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Request Status'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _requestStream,
        builder: (context, snapshot) {
          final request = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting || request == null) {
            return Center(child: _buildWaitingUI());
          }

          // If still pending or no mechanic assigned
          if (request['status'] == 'pending' || request['mechanic_id'] == null) {
            return Center(child: _buildWaitingUI());
          }

          // Mechanic assigned!
          return FutureBuilder<Map<String, dynamic>?>(
            future: _fetchMechanicProfile(request['mechanic_id']),
            builder: (context, mechanicSnap) {
              if (mechanicSnap.connectionState != ConnectionState.done || mechanicSnap.data == null) {
                return Center(child: _buildWaitingUI());
              }
              return _buildConnectedUI(request, mechanicSnap.data!);
            },
          );
        },
      ),
    );
  }
}

// --- Dummy call dialog for demonstration
class CallMechanicDialog extends StatelessWidget {
  final String mechanicName;
  final String phoneNumber;
  const CallMechanicDialog({
    Key? key,
    required this.mechanicName,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Call $mechanicName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Phone Number:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone, color: Colors.green[800]),
              const SizedBox(width: 8),
              Text(phoneNumber, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pretending to call...')));
          },
          icon: const Icon(Icons.call),
          label: const Text('CALL NOW'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }
}
