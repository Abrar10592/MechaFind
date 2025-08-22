import 'dart:math' as math;

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
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class UserHomePage extends StatefulWidget {
  final bool isGuest;
  const UserHomePage({super.key, this.isGuest = false});

  @override
  State createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> with WidgetsBindingObserver {
  String? userName;
  String currentLocation = 'Getting location...';
  double? userLat;
  double? userLng;
  List<Map<String, dynamic>> nearbyMechanics = [];
  List<Map<String, dynamic>> activeRequests = [];
  RealtimeChannel? _requestSubscription;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationServiceAndLoad();
    _setupRealtimeActiveRequests();
    if (supabase.auth.currentUser != null) {
      MessageNotificationService().refresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveRequests();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - refreshing active requests');
      _loadActiveRequests();
      // Reestablish subscription if needed
      if (_requestSubscription == null) {
        _setupRealtimeActiveRequests();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeActiveRequests() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Unsubscribe existing subscription if any
    _requestSubscription?.unsubscribe();

    // Initial load of active requests
    _loadActiveRequests();

    // Setup real-time subscription for immediate updates
    final channelName = 'public:requests:user_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    print('🔄 Setting up real-time subscription: $channelName');
    
    _requestSubscription = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            print('🔄 Real-time request update: ${payload.eventType}');
            print('🔄 Record data: ${payload.newRecord}');
            
            // Reload active requests when any change occurs
            if (mounted) {
              _loadActiveRequests();
            }
          },
        )
        .subscribe((status, [error]) {
          print('📡 Request subscription status: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('✅ Real-time subscription active for user home');
          } else if (status == RealtimeSubscribeStatus.closed) {
            print('❌ Real-time subscription closed - attempting to reconnect');
            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _setupRealtimeActiveRequests();
              }
            });
          }
          if (error != null) {
            print('❌ Request subscription error: $error');
          }
        });
  }

  Future<void> _loadActiveRequests() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Load all active requests (pending and accepted) to show their current status
      final response = await supabase
          .from('requests')
          .select('*')
          .eq('user_id', user.id)
          .or('status.eq.pending,status.eq.accepted')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          activeRequests = List<Map<String, dynamic>>.from(response);
        });
        print('📊 Active requests loaded: ${activeRequests.length}');
        
        // Debug: Print the requests to see what we're getting
        for (var req in activeRequests) {
          print('🔍 Request ${req['id']}: status=${req['status']}, mechanic_id=${req['mechanic_id']}, type=${req['request_type']}');
        }
      }
    } catch (e) {
      print('❌ Error loading active requests: $e');
    }
  }

  Future<void> refreshActiveRequestsData() async {
    print('🔄 Manually refreshing active requests data');
    await _loadActiveRequests();
    // Also refresh the real-time subscription
    _setupRealtimeActiveRequests();
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
    // Filter requests to show pending and accepted requests
    final validActiveRequests = activeRequests.where((r) {
      final status = (r['status'] ?? '').toLowerCase();
      
      // Show requests that are:
      // 1. Accepted (with mechanic assigned) - fully active
      // 2. Pending (might have mechanic assigned or not) - waiting for mechanic
      return status == 'accepted' || status == 'pending';
    }).toList();
    
    // Prioritize emergency requests
    final emergencyReq = validActiveRequests.firstWhere(
          (r) => (r['request_type'] ?? 'normal') == 'emergency',
      orElse: () => {},
    );
    if (emergencyReq.isNotEmpty) {
      return [emergencyReq];
    }
    
    // Return normal requests
    return validActiveRequests
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
          String subtitle;
          
          final status = (req['status'] ?? '').toLowerCase();
          final mechanicId = req['mechanic_id'];
          
          switch (status) {
            case 'pending':
              statusColor = Colors.orange;
              subtitle = mechanicId != null 
                  ? "Status: Pending (Mechanic assigned)\nVehicle: ${req['vehicle'] ?? '-'}\nDescription: ${req['description'] ?? '-'}"
                  : "Status: Looking for mechanic\nVehicle: ${req['vehicle'] ?? '-'}\nDescription: ${req['description'] ?? '-'}";
              break;
            case 'accepted':
              statusColor = Colors.green;
              subtitle = "Status: Accepted\nVehicle: ${req['vehicle'] ?? '-'}\nDescription: ${req['description'] ?? '-'}";
              break;
            default:
              statusColor = Colors.grey;
              subtitle = "Status: ${req['status']}\nVehicle: ${req['vehicle'] ?? '-'}\nDescription: ${req['description'] ?? '-'}";
          }
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              onTap: () async {
                if ((req['request_type'] ?? 'normal') == 'emergency') {
                  await Navigator.pushNamed(
                    context,
                    '/active_emergency_route',
                    arguments: {
                      'requestId': req['id'],
                      'userLocation': LatLng(userLat!, userLng!),
                    },
                  );
                  
                  // Refresh data when returning from emergency route
                  print('🔄 Returned from emergency route, refreshing data');
                  await refreshActiveRequestsData();
                } else {
                  if (mechanicId != null) {
                    _showActiveRequestMechanicDetails(req);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Still looking for a mechanic...')),
                    );
                  }
                }
              },
              leading: CircleAvatar(
                backgroundColor: statusColor,
                child: Icon(
                  status == 'pending' && mechanicId == null 
                      ? Icons.search 
                      : Icons.build, 
                  color: Colors.white
                ),
              ),
              title: Text("Request for Mechanic"),
              subtitle: Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: status == 'pending' && mechanicId == null
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
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
