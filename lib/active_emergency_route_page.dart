import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Dummy popup dialog for Call button
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: () {
            // Dummy call behavior
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pretending to call...')),
            );
          },
          icon: const Icon(Icons.call),
          label: const Text('CALL NOW'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }
}

/// Dummy Messaging Screen to simulate chat
class DummyMessageScreen extends StatefulWidget {
  final String mechanicName;

  const DummyMessageScreen({Key? key, required this.mechanicName}) : super(key: key);

  @override
  State<DummyMessageScreen> createState() => _DummyMessageScreenState();
}

class _DummyMessageScreenState extends State<DummyMessageScreen> {
  final List<String> _messages = [];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.mechanicName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('No messages yet. Say hi!'))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index]; // Reverse order
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveEmergencyRoutePage extends StatelessWidget {
  final LatLng userLocation;
  final Map mechanic;

  const ActiveEmergencyRoutePage({
    Key? key,
    required this.userLocation,
    required this.mechanic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mechanicLocation = LatLng(23.7900, 90.4050); // Demo mechanic location

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Mechanic Connected'),
      ),
      body: Column(
        children: [
          // MAP
          SizedBox(
            height: 260,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (userLocation.latitude + mechanicLocation.latitude) / 2,
                  (userLocation.longitude + mechanicLocation.longitude) / 2,
                ),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.mechfind',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [userLocation, mechanicLocation],
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 28),
                    ),
                    Marker(
                      point: mechanicLocation,
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
                      backgroundImage: AssetImage(mechanic['photoUrl'] ?? ''),
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
                              const SizedBox(width: 10),
                              Text(mechanic['distance'] ?? '',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Status: ${mechanic['status'] ?? ''}',
                            style: TextStyle(
                              color: (mechanic['status'] == 'Online') ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: -4,
                            children: (mechanic['services'] as List)
                                .map((service) => Chip(
                              label: Text(service, style: const TextStyle(fontSize: 11)),
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
                        showDialog(
                          context: context,
                          builder: (_) => CallMechanicDialog(
                            mechanicName: mechanic['name'] ?? 'Mechanic',
                            phoneNumber: mechanic['phone'] ?? '01700-000000',
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
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DummyMessageScreen(mechanicName: mechanic['name'] ?? 'Mechanic'),
                        ));
                      },
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text("Message"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(110, 38),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
