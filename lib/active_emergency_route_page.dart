import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_home.dart';
class ActiveEmergencyRoutePage extends StatefulWidget {
  final String requestId;
  final LatLng userLocation;
  const ActiveEmergencyRoutePage({
    super.key,
    required this.requestId,
    required this.userLocation,
  });

  @override
  State createState() => _ActiveEmergencyRoutePageState();
}

class _ActiveEmergencyRoutePageState extends State<ActiveEmergencyRoutePage> {
  late Stream<Map<String, dynamic>?> _requestStream;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🚀 ActiveEmergencyRoutePage opened for requestId=${widget.requestId}');
    debugPrint('🚀 Initial userLocation = ${widget.userLocation}');
    _requestStream = Supabase.instance.client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.requestId)
        .limit(1)
        .map((events) {
      debugPrint('📡 Supabase stream emitted event list: $events');
      if (events.isNotEmpty) {
        final row = events.first;
        debugPrint('📡 Row keys: ${row.keys}');
        debugPrint('📡 Row data: $row');
        return row;
      }
      return null;
    });
  }

  Future<Map<String, dynamic>?> _fetchMechanicProfile(String mechanicId) async {
    debugPrint('🔍 Fetching mechanic profile for ID=$mechanicId');
    try {
      final res = await Supabase.instance.client
          .from('mechanics')
          .select('''
            rating,
            users(full_name, phone, image_url),
            mechanic_services(services(name))
          ''')
          .eq('id', mechanicId)
          .maybeSingle();
      debugPrint('📡 Raw mechanic profile result: $res');
      if (res == null) {
        debugPrint('⚠️ No mechanic found for id=$mechanicId');
        return null;
      }
      final List svcList = res['mechanic_services'] ?? [];
      final expertise = svcList
          .map((e) => e['services']?['name'] as String?)
          .whereType<String>()
          .toList();
      debugPrint('🛠 Extracted expertise list: $expertise');
      final data = {
        'rating': res['rating'],
        'full_name': res['users']?['full_name'],
        'phone': res['users']?['phone'],
        'image_url': res['users']?['image_url'],
        'expertise': expertise,
      };
      debugPrint('✅ Final mechanic profile map: $data');
      return data;
    } catch (e, st) {
      debugPrint('❌ Error fetching mechanic profile: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<void> _cancelRequest() async {
    await Supabase.instance.client
        .from('requests')
        .update({'status': 'canceled'})
        .eq('id', widget.requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request canceled')),
      );
    }
  }

  // NEW: Service complete popup
  void _showServiceCompleteDialog(Map<String, dynamic> request) {
    double rating = 0;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate the Service'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reviewController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Write a review',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (rating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please give a rating'),
                    ));
                    return;
                  }

                  try {
                    // 1. Update request status to completed
                    await Supabase.instance.client
                        .from('requests')
                        .update({'status': 'completed'})
                        .eq('id', widget.requestId);

                    // 2. Create review record
                    await Supabase.instance.client.from('reviews').insert({
                      'request_id': widget.requestId,
                      'user_id': request['user_id'],
                      'mechanic_id': request['mechanic_id'],
                      'rating': rating.toInt(),
                      'comment': reviewController.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(context); // Close the dialog

                      // Navigate back to user home page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => UserHomePage()),
                            (Route<dynamic> route) => false,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your feedback!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e, st) {
                    debugPrint('❌ Error submitting review: $e');
                    debugPrint('Stack trace: $st');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }


  Widget _buildWaitingUI([String reason = '']) {
    if (reason.isNotEmpty) {
      debugPrint('⏳ Still waiting… reason: $reason');
    }
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
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
              MarkerLayer(markers: [
                Marker(
                  point: widget.userLocation,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.person_pin_circle,
                      color: Colors.red, size: 32),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text("Searching for mechanics nearby...",
            style: TextStyle(fontSize: 17, color: Colors.blue)),
        const SizedBox(height: 12),
        const Text("Mechanics are connecting...",
            style: TextStyle(fontSize: 15, color: Colors.black54)),
      ],
    );
  }

  Widget _buildLiveMap({
    required LatLng userPos,
    required LatLng mechPos,
  }) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(
            (userPos.latitude + mechPos.latitude) / 2,
            (userPos.longitude + mechPos.longitude) / 2,
          ),
          initialZoom: 14.5,
        ),
        children: [
          TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
          PolylineLayer(polylines: [
            Polyline(
                points: [userPos, mechPos],
                color: Colors.blue,
                strokeWidth: 4),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: userPos,
              width: 34,
              height: 34,
              child: const Icon(Icons.person_pin_circle,
                  color: Colors.red, size: 28),
            ),
            Marker(
              point: mechPos,
              width: 34,
              height: 34,
              child: const Icon(Icons.build, color: Colors.green, size: 28),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMechanicCard(Map mechanic) {
    return Container(
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
                backgroundImage: (mechanic['image_url'] != null &&
                    mechanic['image_url'].toString().isNotEmpty)
                    ? NetworkImage(mechanic['image_url'])
                    : null,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['full_name'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                        Text(" ${mechanic['rating'] ?? ''}",
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Phone: ${mechanic['phone'] ?? '-'}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: -4,
                      children: (mechanic['expertise'] as List? ?? [])
                          .map((s) => Chip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.blue[50],
                      ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text("Call"),
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  if (mechanic['phone'] != null) {
                    launchUrl(Uri.parse('tel:${mechanic['phone']}'));
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text("Chat"),
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat not implemented')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text("Profile"),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title:
                        Text(mechanic['full_name'] ?? 'Profile'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${mechanic['phone'] ?? '-'}'),
                            const SizedBox(height: 8),
                            Text(
                                'Expertise: ${(mechanic['expertise'] as List?)?.join(", ") ?? "-"}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'))
                        ],
                      ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Emergency Request Status'),
          backgroundColor: Colors.blue),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _requestStream,
        builder: (context, snapshot) {
          final request = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting ||
              request == null) {
            return _buildWaitingUI('Stream loading or null request');
          }

          final status =
              request['status']?.toString().toLowerCase().trim() ?? '';
          if (status != 'accepted' ||
              request['mechanic_id'] == null ||
              request['mech_lat'] == null ||
              request['mech_lng'] == null) {
            return _buildWaitingUI(
                'Conditions for live tracking not met yet');
          }

          final userLat = double.tryParse(
              request['user_lat']?.toString() ??
                  widget.userLocation.latitude.toString()) ??
              widget.userLocation.latitude;
          final userLng = double.tryParse(
              request['user_lng']?.toString() ??
                  widget.userLocation.longitude.toString()) ??
              widget.userLocation.longitude;
          final mechLat =
              double.tryParse(request['mech_lat']?.toString() ?? '0') ?? 0.0;
          final mechLng =
              double.tryParse(request['mech_lng']?.toString() ?? '0') ?? 0.0;

          final userCurrentPos = LatLng(userLat, userLng);
          final mechanicPos = LatLng(mechLat, mechLng);

          return FutureBuilder<Map<String, dynamic>?>(
            future: _fetchMechanicProfile(
                request['mechanic_id'].toString()),
            builder: (context, mechanicSnap) {
              if (mechanicSnap.connectionState != ConnectionState.done ||
                  mechanicSnap.data == null) {
                return _buildWaitingUI('Mechanic profile still loading');
              }
              return ListView(
                children: [
                  _buildLiveMap(
                      userPos: userCurrentPos, mechPos: mechanicPos),
                  const SizedBox(height: 10),
                  _buildMechanicCard(mechanicSnap.data!),
                  const SizedBox(height: 20),
                  // Cancel button
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Request'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _cancelRequest,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Service complete button
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Service Complete'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: () => _showServiceCompleteDialog(request),


                    ),
                  ),
                ],


              );
            },
          );
        },
      ),
    );
  }
}
