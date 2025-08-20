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
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

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
        .cast<Map<String, dynamic>>()
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
            const SnackBar(content: Text('Location services are required to use this app.')),
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
      final data =
      await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
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

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
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
        final mLat = mech['location_x'] is double
            ? mech['location_x']
            : double.tryParse(mech['location_x'].toString()) ?? 0.0;
        final mLng = mech['location_y'] is double
            ? mech['location_y']
            : double.tryParse(mech['location_y'].toString()) ?? 0.0;
        final distance = _calculateDistanceKm(userLat!, userLng!, mLat, mLng);

        if (distance <= 7.0) {
          final services = (mech['mechanic_services'] as List)
              .map((s) => s['services']?['name'] as String?)
              .whereType<String>()
              .toList();

          // Change here: always use mechanic name if available
          mechanicsList.add({
            'id': mech['id'],
            'name': mech['users']?['full_name'] ?? 'Unnamed',
            'image_url': mech['users']?['image_url'],
            'phone': mech['users']?['phone'],
            'distance': '${distance.toStringAsFixed(1)} km',
            'distance_value': distance,
            'rating': mech['rating'] ?? 0.0,
            'services': services,
            'lat': mLat,
            'lng': mLng,
          });
        }
      }
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
    return activeRequests.any((req) => req['mechanic_id'] == mechId && req['status'] == status);
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign In Required"),
        content: const Text("Please sign in or sign up to request a mechanic."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/signin');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showActiveRequestMechanicDetails(Map request) async {
    try {
      final mechanicId = request['mechanic_id'];
      final mechanic = nearbyMechanics.firstWhere(
            (mech) => mech['id'].toString() == mechanicId.toString(),
        orElse: () => {},
      );
      if (mechanic.isEmpty) {
        final data = await supabase
            .from('mechanics')
            .select('id,rating,users(full_name,profile_pic,phone),mechanic_services(services(name))')
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
        SnackBar(content: Text('Failed to load mechanic details: $e')),
      );
    }
  }

  void _showMechanicDetailsSheet(Map mechanic, Map request) {
    final phone = mechanic['phone'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: mechanic['image_url'] != null && mechanic['image_url'].toString().isNotEmpty
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
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone not available')),
                    );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message feature not implemented')),
                  );
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
                      const SnackBar(content: Text('Request cancelled')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cancel failed: $e')),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Service Complete'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(context);
                  _showServiceCompleteDialog(request);
                },
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // You can keep your existing _showRequestServiceDialog. Not shown for brevity.

  List<Map<String, dynamic>> get _filteredActiveRequests {
    final emergencyReq = activeRequests.firstWhere(
          (r) => (r['request_type'] ?? 'normal') == 'emergency',
      orElse: () => {},
    );
    if (emergencyReq.isNotEmpty) {
      return [emergencyReq];
    }
    return activeRequests
        .where((r) => (r['request_type'] ?? 'normal') == 'normal')
        .toList();
  }

  Widget _activeRequestsSection() {
    final filteredRequests = _filteredActiveRequests;
    if (filteredRequests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("Active Requests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...filteredRequests.map((req) {
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
                  Navigator.pushNamed(
                    context,
                    '/active_emergency_route',
                    arguments: {
                      'requestId': req['id'],
                      'userLocation': LatLng(userLat!, userLng!),
                    },
                  );
                } else {
                  _showActiveRequestMechanicDetails(req);
                }
              },
              leading: CircleAvatar(
                backgroundColor: statusColor,
                child: const Icon(Icons.build, color: Colors.white),
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

  Future _refreshHomePage() async {
    await _checkLocationServiceAndLoad();
    await _fetchUserName();
    await _fetchMechanicsFromDB();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final greetingText = widget.isGuest ? "Welcome" : "Welcome ${userName ?? ''}";

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
                                    style: AppTextStyles.heading.copyWith(
                                        fontSize: 18, fontWeight: FontWeight.bold),
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
                            onPressed: (hasPending || hasAccepted)
                                ? null
                                : () {
                              // GUEST CAN'T REQUEST
                              if (widget.isGuest) {
                                _showLoginRequiredDialog();
                              } else {
                                _showRequestServiceDialog(mech);
                              }
                            },
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

// Keep your _showServiceCompleteDialog and _showRequestServiceDialog as before (no changes here for guest logic)


void _showServiceCompleteDialog(Map request) {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please give a rating')));
                      return;
                    }
                    try {
                      // 1. Update request status to completed
                      await supabase
                          .from('requests')
                          .update({'status': 'completed'})
                          .eq('id', request['id']);

                      // 2. Insert review record
                      await supabase.from('reviews').insert({
                        'request_id': request['id'],
                        'user_id': request['user_id'],
                        'mechanic_id': request['mechanic_id'],
                        'rating': rating.toInt(),
                        'comment': reviewController.text.trim(),
                      });

                      if (mounted) {
                        Navigator.pop(context); // Close dialog
                        await _refreshHomePage(); // Refresh home page data
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Thank you for your feedback!'),
                          duration: Duration(seconds: 2),
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Failed to submit: ${e.toString()}')));
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          });
        });
  }

}

class _showRequestServiceDialog {
  _showRequestServiceDialog(Map<String, dynamic> mech);
    
}
