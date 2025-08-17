import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'location_service.dart';
import 'widgets/emergency_button.dart';
import 'widgets/bottom_navbar.dart';
import 'widgets/profile_avatar.dart';
import 'services/message_notification_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // for calling

class UserHomePage extends StatefulWidget {
  final bool isGuest;
  const UserHomePage({super.key, this.isGuest = false});

  @override
  State createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? userName;
  String currentLocation = 'Getting location...';
  double? userLat;
  double? userLng;
  List<Map<String, dynamic>> nearbyMechanics = [];
  List<Map<String, dynamic>> activeRequests = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkLocationServiceAndLoad();
    _listenActiveRequests();
    
    // Refresh message notifications when home page loads
    if (supabase.auth.currentUser != null) {
      MessageNotificationService().refresh();
    }
  }

  void _listenActiveRequests() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    supabase
        .from('requests')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
        .where((row) =>
    row['user_id'] == user.id &&
        (row['status'] == 'pending' || row['status'] == 'accepted'))
        .toList())
        .listen((filteredRows) {
      setState(() {
        activeRequests = List<Map<String, dynamic>>.from(filteredRows);
      });
    });
  }

  Future _checkLocationServiceAndLoad() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location services are required to use this app.')),
          );
        }
        return;
      }
    }
    await fetchUserLocation();
    if (widget.isGuest) {
      await _insertGuestSession();
    } else {
      await _fetchUserName();
    }
    await _fetchMechanicsFromDB();
  }

  Future _insertGuestSession() async {
    try {
      final sessionInfo = 'Guest session at ${DateTime.now().toIso8601String()}';
      await supabase.from('guests').insert({'session_info': sessionInfo});
    } catch (e) {
      print("❌ Guest insert error: $e");
    }
  }

  Future _fetchUserName() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      setState(() {
        userName = data?['full_name'] ?? '';
      });
    } catch (e) {
      print("❌ Name fetch error: $e");
    }
  }

  Future fetchUserLocation() async {
    final location = await LocationService.getCurrentLocation(context);
    if (location != null) {
      final parts = location.split(', ');
      userLat = double.tryParse(parts[0]);
      userLng = double.tryParse(parts[1]);
      final address = await getAddressFromLatLng(userLat!, userLng!);
      setState(() {
        currentLocation = address;
      });
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks.first;
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('⚠️ Reverse geocode error: $e');
      return 'Location not found';
    }
  }

  double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  Future _fetchMechanicsFromDB() async {
    if (userLat == null || userLng == null) return;

    try {
      // First fetch all mechanics with their locations
      final mechanicData = await supabase.from('mechanics').select('''
          id,
          rating,
          location_x,
          location_y,
          users(full_name, image_url, phone),
          mechanic_services(service_id, services(name))
          ''');

      List<Map<String, dynamic>> mechanicsList = [];

      for (final mech in mechanicData) {
        // Parse mechanic's location coordinates
        final mLat = mech['location_x'] is double
            ? mech['location_x']
            : double.tryParse(mech['location_x'].toString()) ?? 0.0;
        final mLng = mech['location_y'] is double
            ? mech['location_y']
            : double.tryParse(mech['location_y'].toString()) ?? 0.0;

        // Calculate distance in kilometers
        final distance = _calculateDistanceKm(userLat!, userLng!, mLat, mLng);

        // Only include mechanics within 7km radius
        if (distance <= 7.0) {
          final services = (mech['mechanic_services'] as List<dynamic>)
              .map((s) => s['services']?['name'] as String?)
              .whereType<String>()
              .toList();

          mechanicsList.add({
            'id': mech['id'],
            'name': mech['users']?['full_name'] ?? 'Unnamed',
            'image_url': mech['users']?['image_url'],
            'phone': mech['users']?['phone'],
            'distance': '${distance.toStringAsFixed(1)} km',
            'distance_value': distance, // Store numerical value for sorting
            'rating': mech['rating'] ?? 0.0,
            'services': services,
            'lat': mLat, // Store latitude for mapping
            'lng': mLng, // Store longitude for mapping
          });
        }
      }

      // Sort mechanics by distance (nearest first)
      mechanicsList.sort((a, b) => a['distance_value'].compareTo(b['distance_value']));

      setState(() {
        nearbyMechanics = mechanicsList;
      });

    } catch (e) {
      print("❌ Fetch mechanics error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mechanics: ${e.toString()}')),
        );
      }
    }
  }

  bool _isRequestActiveForMechanic(String mechId, String status) {
    return activeRequests.any(
            (req) => req['mechanic_id'] == mechId && req['status'] == status);
  }

  /// Tap active request → show bottom sheet with cancel
  void _showActiveRequestMechanicDetails(Map<String, dynamic> request) async {
    try {
      final mechanicId = request['mechanic_id'];
      final mechanic = nearbyMechanics.firstWhere(
              (mech) => mech['id'].toString() == mechanicId.toString(),
          orElse: () => {});
      if (mechanic.isEmpty) {
        final data = await supabase
            .from('mechanics')
            .select(
            'id,rating,users(full_name,profile_pic,phone),mechanic_services(services(name))')
            .eq('id', mechanicId)
            .maybeSingle();
        if (data == null) throw Exception("Mechanic not found");
        final services = (data['mechanic_services'] as List)
            .map((s) => s['services']?['name'] as String?)
            .whereType<String>()
            .toList();
        final user = data['users'] ?? {};
        final fetchedMech = {
          'id': data['id'],
          'name': user['full_name'] ?? 'Unnamed',
          'image_url': user['profile_pic'],
          'phone': user['phone'],
          'rating': data['rating'] ?? 0.0,
          'services': services,
        };
        _showMechanicDetailsSheet(fetchedMech, request);
      } else {
        _showMechanicDetailsSheet(mechanic, request);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load mechanic details: $e')));
    }
  }

  void _showMechanicDetailsSheet(
      Map<String, dynamic> mechanic, Map<String, dynamic> request) {
    final phone = mechanic['phone'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ↔ more space
      builder: (context) => Padding(
        padding:
        const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40), // ↔ increased bottom
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: mechanic['image_url'] != null &&
                mechanic['image_url'].toString().isNotEmpty
                ? CircleAvatar(
              backgroundImage: NetworkImage(mechanic['image_url']),
              radius: 30,
            )
                : const CircleAvatar(radius: 30, child: Icon(Icons.person)),
            title: Text(mechanic['name'] ?? ''),
            subtitle: Text(
                'Rating: ${mechanic['rating']}\nServices: ${mechanic['services']?.join(", ")}'),
          ),
          Text('Request Status: ${request['status']}'),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8, // horizontal space between buttons
            runSpacing: 8, // vertical space when wrapping
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone not available')));
                    return;
                  }
                  final Uri callUri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(callUri)) {
                    await launchUrl(callUri);
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.message),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Message feature not implemented')));
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await supabase
                        .from('requests')
                        .update({'status': 'canceled'})
                        .eq('id', request['id']);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request cancelled')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cancel failed: $e')));
                  }
                },
              ),
            ],
          )

        ]),
      ),
    );
  }

  /// Your existing _showRequestServiceDialog unchanged
  void _showRequestServiceDialog(Map<String, dynamic> mechanic) {
    final vehicleController = TextEditingController();
    final problemController = TextEditingController();
    XFile? pickedImage;
    final picker = ImagePicker();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> handleSubmit() async {
            final user = supabase.auth.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please login first')));
              return;
            }
            final existing = await supabase
                .from('requests')
                .select()
                .eq('user_id', user.id)
                .eq('status', 'pending');
            if (existing.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You already have a pending request')));
              return;
            }
            if (vehicleController.text.isEmpty ||
                problemController.text.isEmpty ||
                pickedImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields and add image')));
              return;
            }
            if (userLat == null || userLng == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location not available')));
              return;
            }
            setState(() => loading = true);
            try {
              final bucketName = 'request-photos';
              final fileExt = pickedImage!.path.split('.').last;
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
              final filePath = 'requests/${user.id}/$fileName';
              await supabase.storage
                  .from(bucketName)
                  .upload(filePath, File(pickedImage!.path));
              final imageUrl = await supabase.storage
                  .from(bucketName)
                  .createSignedUrl(filePath, 86400);
              await supabase.from('requests').insert({
                'user_id': user.id,
                'mechanic_id': mechanic['id'],
                'status': 'pending',
                'vehicle': vehicleController.text.trim(),
                'description': problemController.text.trim(),
                'image': imageUrl,
                'lat': userLat.toString(),
                'lng': userLng.toString(),
                'request_type': 'normal',
              });
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            } finally {
              setState(() => loading = false);
            }
          }

          return AlertDialog(
            title: Text('Request Service from ${mechanic['name']}'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  Text(currentLocation),
                  TextField(
                    controller: vehicleController,
                    decoration:
                    const InputDecoration(labelText: 'Vehicle Model'),
                  ),
                  TextField(
                    controller: problemController,
                    decoration: const InputDecoration(labelText: 'Problem'),
                    maxLines: 3,
                  ),
                  pickedImage != null
                      ? Image.file(File(pickedImage!.path), height: 100)
                      : const Text('No image selected'),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    onPressed: () async {
                      final img = await picker.pickImage(
                          source: ImageSource.camera, imageQuality: 70);
                      if (img != null) setState(() => pickedImage = img);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Pick Image'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: loading ? null : handleSubmit,
                child: Text(loading ? 'Submitting...' : 'Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _activeRequestsSection() {
    if (activeRequests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("Active Requests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...activeRequests.map((req) {
          Color statusColor;
          switch ((req['status'] ?? '').toLowerCase()) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'accepted':
              statusColor = Colors.green;
              break;
            default:
              statusColor = Colors.grey;
          }
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              onTap: () {
                if ((req['request_type'] ?? 'normal') == 'emergency') {
                  Navigator.pushNamed(context, '/active_emergency_route', arguments: req);
                } else {
                  _showActiveRequestMechanicDetails(req);
                }
              },

              leading: CircleAvatar(
                backgroundColor: statusColor,
                child:
                const Icon(Icons.build, color: Colors.white),
              ),
              title: const Text("Request for Mechanic"),
              subtitle: Text(
                "Status: ${req['status']}\nVehicle: ${req['vehicle'] ?? '-'}\nDescription: ${req['description'] ?? '-'}",
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  Future<void> _refreshHomePage() async {
    await _checkLocationServiceAndLoad();
    await _fetchUserName();
    await _fetchMechanicsFromDB();
    // No need to re-listen to activeRequests stream because it updates live automatically
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final greetingText =
    widget.isGuest ? "Welcome" : "Welcome ${userName ?? ''}";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          greetingText,
          style: AppTextStyles.heading.copyWith(color: Colors.white),
        ),
        actions: [
          if (!widget.isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CurrentUserAvatar(
                radius: 18,
                showBorder: true,
                borderColor: Colors.white,
                onTap: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshHomePage,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentLocation,
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: EmergencyButton(),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Nearby Mechanics',
                style: AppTextStyles.heading.copyWith(fontSize: FontSizes.subHeading),
              ),
            ),
            const SizedBox(height: 10),
            if (nearbyMechanics.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No mechanics found."),
              )
            else
              Column(
                children: nearbyMechanics.map((mech) {
                  final hasPending = _isRequestActiveForMechanic(mech['id'], 'pending');
                  final hasAccepted = _isRequestActiveForMechanic(mech['id'], 'accepted');

                  Color btnColor = AppColors.accent;
                  String btnText = "Request Service";

                  if (hasPending) {
                    btnColor = Colors.orange;
                    btnText = "Request Pending";
                  } else if (hasAccepted) {
                    btnColor = Colors.green;
                    btnText = "Request Accepted";
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            mech['image_url'] != null && mech['image_url'].toString().isNotEmpty
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.network(
                                mech['image_url'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                                ),
                              ),
                            )
                                : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mech['name'],
                                    style: AppTextStyles.heading.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Distance: ${mech['distance']}'),
                                  Text('Rating: ${mech['rating']}'),
                                  Text('Services: ${mech['services']?.join(', ')}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
                            onPressed: (hasPending || hasAccepted) ? null : () => _showRequestServiceDialog(mech),
                            child: Text(btnText),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            _activeRequestsSection(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushNamed(context, '/messages');
              break;
            case 3:
              Navigator.pushNamed(context, '/history');
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

}