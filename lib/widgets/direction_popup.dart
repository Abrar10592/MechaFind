import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:mechfind/mechanic/chat_screen.dart';
import 'package:mechfind/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectionPopup extends StatefulWidget {
  final latlng.LatLng requestLocation;
  final String phone;
  final String name;
  final String requestId;
  final String user_id;
  final VoidCallback onReject;
  final String imageUrl;
  final VoidCallback onMinimize;

  const DirectionPopup({
    super.key,
    required this.requestLocation,
    required this.phone,
    required this.name,
    required this.requestId,
    required this.onReject,
    required this.onMinimize,
    required this.user_id,
    this.imageUrl = '',
  });

  @override
  State<DirectionPopup> createState() => _DirectionPopupState();
}

class _DirectionPopupState extends State<DirectionPopup> 
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final SupabaseClient supabase = Supabase.instance.client;

  latlng.LatLng? _mechanicLocation;
  List<List<latlng.LatLng>> _routes = [];
  StreamSubscription<LocationData>? _locationSubscription;

  double _currentZoom = 14;
  bool _userMovedMap = false;
  double? _distanceInMeters;
  bool _isLoadingRoute = false;
  double? _mechanicHeading; // Direction the mechanic is facing

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initLocation();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    _slideController.forward();
    _buttonController.forward();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locData = await _location.getLocation();
    _updateMechanicLocation(locData);

    _locationSubscription = _location.onLocationChanged.listen((locData) {
      _updateMechanicLocation(locData);
    });
  }

  void _updateMechanicLocation(LocationData locData) {
    final newLoc = latlng.LatLng(locData.latitude!, locData.longitude!);
    setState(() {
      _mechanicLocation = newLoc;
      _mechanicHeading = locData.heading; // Capture the direction user is facing
    });

    if (!_userMovedMap) {
      _mapController.move(newLoc, _currentZoom);
    }

    _fetchRoutes(newLoc, widget.requestLocation);
  }

  Future<void> _fetchRoutes(latlng.LatLng start, latlng.LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });

    final accessToken =
        'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?geometries=geojson&overview=full&alternatives=true&access_token=$accessToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;

        if (routes.isEmpty) {
          debugPrint('No routes found');
          setState(() {
            _isLoadingRoute = false;
          });
          return;
        }

        List<List<latlng.LatLng>> parsedRoutes = [];
        double? minDistance;

        for (var route in routes) {
          final coords = route['geometry']['coordinates'] as List;
          final points = coords
              .map((c) => latlng.LatLng(c[1] as double, c[0] as double))
              .toList();
          parsedRoutes.add(points);

          final dist = route['distance'] as double;
          if (minDistance == null || dist < minDistance) {
            minDistance = dist;
          }
        }

        setState(() {
          _routes = parsedRoutes;
          _distanceInMeters = minDistance;
          _isLoadingRoute = false;
        });
      } else {
        debugPrint('Failed to get routes: ${response.statusCode}');
        setState(() {
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _launchPhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Reject Request", style: AppTextStyles.heading),
        content: Text(
          "Are you sure you want to reject this request?",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('requests')
                    .update({
                      'mechanic_id': null,
                      'status': 'pending',
                      'mech_lat': null,
                      'mech_lng': null,
                    })
                    .eq('id', widget.requestId);
                print(
                  'Request ${widget.requestId} rejected: Cleared mechanic_id, mech_lat, mech_lng, and set status to pending',
                );
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close modal
                widget.onReject(); // Trigger UI update in MechanicLandingScreen
              } catch (e) {
                print('Error rejecting request ${widget.requestId}: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error rejecting request: $e')),
                );
              }
            },
            child: Text("Yes", style: AppTextStyles.label),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessToken =
        'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
    
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.1) {
          widget.onMinimize();
          _locationSubscription?.pause();
          print('Modal minimized to bubble, location subscription paused');
        } else {
          if (_locationSubscription?.isPaused ?? false) {
            _locationSubscription?.resume();
            print('Modal restored, location subscription resumed');
          }
        }
        return true;
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.95,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                    AppColors.primary.withOpacity(0.02),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Header with gradient
                  _buildModernHeader(),
                  
                  // Main map content
                  Positioned.fill(
                    top: 80,
                    bottom: 90,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Listener(
                            onPointerDown: (_) => _userMovedMap = true,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter:
                                    _mechanicLocation ?? widget.requestLocation,
                                initialZoom: _currentZoom,
                                onPositionChanged:
                                    (MapCamera camera, bool hasGesture) {
                                      if (hasGesture) {
                                        _currentZoom = camera.zoom;
                                      }
                                    },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken",
                                  additionalOptions: {
                                    'accessToken': accessToken,
                                    'id': 'mapbox.mapbox-traffic-v1',
                                  },
                                ),
                                MarkerLayer(
                                  markers: [
                                    // User location marker - modern and smaller
                                    Marker(
                                      point: widget.requestLocation,
                                      width: 40,
                                      height: 40,
                                      child: AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _pulseAnimation.value,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.red.shade400,
                                                    Colors.red.shade600,
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.red.withOpacity(0.4),
                                                    blurRadius: 10,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.person_pin_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Mechanic location marker - modern and smaller
                                    if (_mechanicLocation != null)
                                      Marker(
                                        point: _mechanicLocation!,
                                        width: 40,
                                        height: 40,
                                        child: Stack(
                                          children: [
                                            // Direction indicator background
                                            if (_mechanicHeading != null && _mechanicHeading! >= 0)
                                              Transform.rotate(
                                                angle: (_mechanicHeading! * 3.14159) / 180,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: RadialGradient(
                                                      center: const Alignment(0, -0.3),
                                                      radius: 0.8,
                                                      colors: [
                                                        AppColors.primary.withOpacity(0.3),
                                                        AppColors.primary.withOpacity(0.1),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            // Main mechanic marker
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primary.withOpacity(0.8),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary.withOpacity(0.4),
                                                    blurRadius: 10,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.build_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            // Direction arrow
                                            if (_mechanicHeading != null && _mechanicHeading! >= 0)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: Transform.rotate(
                                                  angle: (_mechanicHeading! * 3.14159) / 180,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.orange.shade400,
                                                          Colors.orange.shade600,
                                                        ],
                                                      ),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.navigation,
                                                      color: Colors.white,
                                                      size: 10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                // Modern route lines
                                for (final route in _routes)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: route,
                                        strokeWidth: 4.0,
                                        color: route == _routes.first
                                            ? AppColors.primary
                                            : AppColors.primary.withOpacity(0.4),
                                        borderColor: Colors.white,
                                        borderStrokeWidth: 1.5,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Distance indicator
                  if (_distanceInMeters != null)
                    Positioned(
                      top: 100,
                      left: 30,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.straighten,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(_distanceInMeters! / 1000).toStringAsFixed(1)} km',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Loading indicator
                  if (_isLoadingRoute)
                    Positioned(
                      top: 160,
                      left: 30,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Finding best route...',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Location button
                  Positioned(
                    bottom: 180,
                    right: 30,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          onPressed: () {
                            if (_mechanicLocation != null) {
                              _userMovedMap = false;
                              _mapController.move(_mechanicLocation!, _currentZoom);
                            }
                          },
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom action buttons
                  _buildModernBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              // Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Navigation to ${widget.name}',
                      style: AppTextStyles.heading.copyWith(
                        color: Colors.white,
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Emergency Service Request',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Close button
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _showConfirmationDialog,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _buttonController,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
        )),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _launchPhoneCall(widget.phone),
                        icon: const Icon(Icons.phone_rounded, size: 22),
                        label: Text(
                          'Call Customer',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: widget.user_id,
                                receiverName: widget.name,
                                receiverImageUrl: widget.imageUrl,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                        label: Text(
                          'Message',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
