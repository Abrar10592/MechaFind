import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:mechfind/utils.dart';
import 'widgets/emergency_form_dialog.dart';
import 'widgets/service_booking_dialog.dart';

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

class _UserHomePageState extends State<UserHomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  String? userName;
  String currentLocation = tr('getting_location');
  double? userLat;
  double? userLng;
  List<Map<String, dynamic>> nearbyMechanics = [];
  List<Map<String, dynamic>> activeRequests = [];
  RealtimeChannel? _requestSubscription;
  final supabase = Supabase.instance.client;

  // Animation controllers for beautiful UI
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize beautiful animations
    _initAnimations();
    
    _checkLocationServiceAndLoad();
    _setupRealtimeActiveRequests();
    if (supabase.auth.currentUser != null) {
      MessageNotificationService().refresh();
    }
  }
  
  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      if (_requestSubscription == null) {
        _setupRealtimeActiveRequests();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestSubscription?.unsubscribe();
    _periodicRefreshTimer?.cancel();
    
    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    
    super.dispose();
  }

  void _setupRealtimeActiveRequests() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    // Unsubscribe existing subscription
    _requestSubscription?.unsubscribe();
    
    // Load active requests first
    _loadActiveRequests();
    
    // Create unique channel name with timestamp
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
        print('🔄 Request type: ${payload.newRecord['request_type']}');
        
        // Force immediate refresh when any change is detected
        if (mounted) {
          print('🔄 Triggering _loadActiveRequests due to real-time update');
          _loadActiveRequests();
          
          // Also refresh mechanics to update button states
          _fetchMechanicsFromDB();
        }
      },
    )
        .subscribe((status, [error]) {
      print('📡 Request subscription status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Real-time subscription active for user home');
      } else if (status == RealtimeSubscribeStatus.closed) {
        print('❌ Real-time subscription closed - attempting to reconnect');
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
    
    // Also set up a periodic refresh as a fallback
    _setupPeriodicRefresh();
  }

  Timer? _periodicRefreshTimer;
  
  void _setupPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        print('🔄 Periodic refresh of active requests');
        _loadActiveRequests();
      } else {
        timer.cancel();
      }
    });
  }

  Future _loadActiveRequests() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
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
        for (var req in activeRequests) {
          print('🔍 Request ${req['id']}: status=${req['status']}, mechanic_id=${req['mechanic_id']}, type=${req['request_type']}');
        }
      }
    } catch (e) {
      print('❌ Error loading active requests: $e');
    }
  }

  Future refreshActiveRequestsData() async {
    print('🔄 Manually refreshing active requests data');
    await _loadActiveRequests();
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
      final data = await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
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

  Future getAddressFromLatLng(double lat, double lng) async {
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
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
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
        title: Text(tr("sign_in_required")),
        content: Text(tr("please_sign_in_to_request_mechanic")),
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
                '${tr("rating")}: ${mechanic['rating']}\n${tr("services")}: ${mechanic['services']?.join(", ")}'),
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
                icon: const Icon(Icons.edit),
                label: const Text('Edit Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  _showEditRequestDialog(request);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text('Add Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  Navigator.pop(context);
                  _showRequestServiceDialog(mechanic);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await supabase.from('requests').update({
                      'status': 'canceled',
                      'mechanic_id': null,
                      'mech_lat': null,
                      'mech_lng': null,
                    }).eq('id', request['id']);
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

  Future _refreshHomePage() async {
    await _checkLocationServiceAndLoad();
    await _fetchUserName();
    await _fetchMechanicsFromDB();
    setState(() {});
  }

  // The new Emergency Button onPressed handler checking multiple emergency requests:
  void onEmergencyButtonTap() async {
    HapticFeedback.heavyImpact();

    await _loadActiveRequests();

    bool hasPendingEmergency = activeRequests.any((req) =>
    (req['request_type'] ?? '').toString().toLowerCase() == 'emergency' &&
        (req['status'] ?? '').toString().toLowerCase() == 'pending'
    );

    if (hasPendingEmergency) {
      // Show popup that user has pending emergency request already
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr("emergency_request_in_progress")),
          content: Text(
              tr("emergency_request_pending_warning")),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr("ok")),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => const EmergencyFormDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'MechFind',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // This removes the back button
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.gradientStart,
              ],
            ),
          ),
        ),
        actions: [
          if (!widget.isGuest)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: Colors.white,
                    onPressed: () {
                      // Handle notifications
                    },
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Colors.white,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.1 - (_pulseAnimation.value - 1.0),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.tealPrimary.withOpacity(0.06),
                            AppColors.tealPrimary.withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Main content
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshHomePage,
                color: AppColors.tealPrimary,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildModernHeader(),
                    const SizedBox(height: 20),
                    _buildLocationSection(),
                    const SizedBox(height: 24),
                    _buildEmergencySection(),
                    const SizedBox(height: 32),
                    _buildNearbyMechanicsSection(),
                    const SizedBox(height: 24),
                    _buildActiveRequestsSection(),
                    const SizedBox(height: 80), // Extra space for bottom navigation
                  ],
                ),
              ),
            ),
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

  Widget _buildModernHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('welcome_back'),
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: AppFonts.secondaryFont,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!widget.isGuest)
                      Text(
                        userName ?? tr('user'),
                        style: AppTextStyles.heading.copyWith(
                          color: Colors.white,
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Text(
                        tr('guest_user'),
                        style: AppTextStyles.heading.copyWith(
                          color: Colors.white,
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.isGuest)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CurrentUserAvatar(
                          radius: 24,
                          showBorder: false,
                          onTap: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: AppColors.tealPrimary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.tealPrimary,
                    AppColors.tealSecondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealPrimary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Location',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: AppFonts.secondaryFont,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentLocation,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppFonts.primaryFont,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🚨 Emergency Services',
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.primary,
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Need immediate assistance? Our mechanics are ready to help 24/7',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: AppFonts.secondaryFont,
                ),
              ),
              const SizedBox(height: 16),
              EmergencyButton(
                onPressed: onEmergencyButtonTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyMechanicsSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.orangePrimary,
                        AppColors.orangeSecondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.engineering,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Mechanics',
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.primary,
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        '${nearbyMechanics.length} mechanics available',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (nearbyMechanics.isEmpty)
            _buildEmptyMechanicsState()
          else
            Column(
              children: nearbyMechanics.asMap().entries.map((entry) {
                int index = entry.key;
                Map mech = entry.value;
                return _buildModernMechanicCard(mech, index);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMechanicsState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.textSecondary.withOpacity(0.1),
                  AppColors.textSecondary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No mechanics found nearby',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or check back later',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernMechanicCard(Map mech, int index) {
    final hasPending = _isRequestActiveForMechanic(mech['id'], 'pending');
    final hasAccepted = _isRequestActiveForMechanic(mech['id'], 'accepted');
    
    Color btnColor = AppColors.tealPrimary;
    String btnText = tr("request_service");
    IconData btnIcon = Icons.build;
    
    if (hasPending) {
      btnColor = AppColors.orangePrimary;
      btnText = "Request Pending";
      btnIcon = Icons.pending;
    } else if (hasAccepted) {
      btnColor = AppColors.greenPrimary;
      btnText = "Request Accepted";
      btnIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppColors.tealPrimary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (hasPending || hasAccepted) return;
              if (widget.isGuest) {
                _showLoginRequiredDialog();
              } else {
                _showRequestServiceDialog(mech);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image
                      Hero(
                        tag: 'mechanic_${mech['id']}',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.tealPrimary.withOpacity(0.1),
                                AppColors.tealSecondary.withOpacity(0.1),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.tealPrimary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.tealPrimary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: mech['image_url'] != null && mech['image_url'].toString().isNotEmpty
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
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.textSecondary.withOpacity(0.3),
                                            AppColors.textSecondary.withOpacity(0.1),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        size: 40,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.textSecondary.withOpacity(0.3),
                                        AppColors.textSecondary.withOpacity(0.1),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 40,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Mechanic Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mech['name'],
                              style: AppTextStyles.heading.copyWith(
                                fontFamily: AppFonts.primaryFont,
                                color: AppColors.primary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Distance & Rating Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.tealPrimary.withOpacity(0.1),
                                        AppColors.tealSecondary.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: AppColors.tealPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        mech['distance'],
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.tealPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade600,
                                        Colors.amber.shade500,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${mech['rating'] ?? '0.0'}',
                                        style: AppTextStyles.label.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Services
                            if (mech['services'] != null && mech['services'].isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: (mech['services'] as List).take(3).map((service) =>
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.tealPrimary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      service.toString(),
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          btnColor,
                          btnColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: btnColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: Icon(btnIcon, size: 20),
                      label: Text(
                        btnText,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: (hasPending || hasAccepted) ? null : () {
                        if (widget.isGuest) {
                          _showLoginRequiredDialog();
                        } else {
                          _showRequestServiceDialog(mech);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    if (activeRequests.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.greenPrimary,
                        AppColors.greenSecondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('active_requests'),
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.primary,
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        '${activeRequests.length} ${tr("ongoing_requests")}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...activeRequests.map((req) => _buildModernActiveRequestCard(req)),
        ],
      ),
    );
  }

  Widget _buildModernActiveRequestCard(Map request) {
    final status = (request['status'] ?? '').toLowerCase();
    final mechanicId = request['mechanic_id'];
    final isEmergency = (request['request_type'] ?? 'normal') == 'emergency';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'pending':
        statusColor = mechanicId != null ? AppColors.orangePrimary : AppColors.tealPrimary;
        statusText = mechanicId != null ? tr("mechanic_assigned") : tr("finding_mechanic");
        statusIcon = mechanicId != null ? Icons.person_pin : Icons.search;
        break;
      case 'accepted':
        statusColor = AppColors.greenPrimary;
        statusText = tr("en_route");
        statusIcon = Icons.directions_car;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = status;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isEmergency 
              ? AppColors.danger.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isEmergency 
            ? AppColors.danger.withOpacity(0.3)
            : AppColors.tealPrimary.withOpacity(0.2),
          width: isEmergency ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (isEmergency) {
                await Navigator.pushNamed(
                  context,
                  '/active_emergency_route',
                  arguments: {
                    'requestId': request['id'],
                    'userLocation': LatLng(userLat!, userLng!),
                  },
                );
                print('🔄 Returned from emergency route, refreshing data');
                await refreshActiveRequestsData();
              } else {
                if (mechanicId != null) {
                  _showActiveRequestMechanicDetails(request);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Still looking for a mechanic...')),
                  );
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Request Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isEmergency ? '🚨 Emergency Request' : 'Service Request',
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 16,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEmergency) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'URGENT',
                                  style: AppTextStyles.label.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: AppTextStyles.body.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (request['vehicle'] != null)
                          Text(
                            'Vehicle: ${request['vehicle']}',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (request['description'] != null)
                          Text(
                            request['description'],
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  
                  // Loading indicator or status
                  if (status == 'pending' && mechanicId == null)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                    await supabase
                        .from('requests')
                        .update({'status': 'completed'})
                        .eq('id', request['id']);
                    await supabase.from('reviews').insert({
                      'request_id': request['id'],
                      'user_id': request['user_id'],
                      'mechanic_id': request['mechanic_id'],
                      'rating': rating.toInt(),
                      'comment': reviewController.text.trim(),
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      await _refreshHomePage();
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
      },
    );
  }

  void _showRequestServiceDialog(Map mech) {
    showDialog(
      context: context,
      builder: (context) => ServiceBookingDialog(
        mechanic: Map<String, dynamic>.from(mech),
        onRequestSubmitted: () {
          // Force refresh when a request is submitted
          print('🔄 Request submitted callback - refreshing data');
          _loadActiveRequests();
          _fetchMechanicsFromDB();
        },
      ),
    );
  }

  void _showEditRequestDialog(Map request) {
    final TextEditingController vehicleController = TextEditingController(text: request['vehicle'] ?? '');
    final TextEditingController descriptionController = TextEditingController(text: request['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Service Request',
          style: AppTextStyles.heading.copyWith(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleController,
                style: AppTextStyles.body.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.directions_car, color: Colors.white70),
                  hintText: "Vehicle Model",
                  hintStyle: AppTextStyles.label.copyWith(color: Colors.white60),
                  filled: true,
                  fillColor: AppColors.primary.withOpacity(0.25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                style: AppTextStyles.body.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.build, color: Colors.white70),
                  hintText: "Describe the service you need",
                  hintStyle: AppTextStyles.label.copyWith(color: Colors.white60),
                  filled: true,
                  fillColor: AppColors.primary.withOpacity(0.25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                await supabase.from('requests').update({
                  'vehicle': vehicleController.text,
                  'description': descriptionController.text,
                }).eq('id', request['id']);
                
                Navigator.pop(context); // Close edit dialog
                Navigator.pop(context); // Close mechanic details sheet
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Refresh active requests
                await refreshActiveRequestsData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update request: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Update Request',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
