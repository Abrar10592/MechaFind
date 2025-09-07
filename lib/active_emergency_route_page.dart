import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_home.dart';
import 'utils.dart';
class ActiveEmergencyRoutePage extends StatefulWidget {
  final String requestId;
  final LatLng userLocation;
  const ActiveEmergencyRoutePage({
    super.key,
    required this.requestId,
    required this.userLocation,
  });

  @override
  State<ActiveEmergencyRoutePage> createState() => _ActiveEmergencyRoutePageState();
}

class _ActiveEmergencyRoutePageState extends State<ActiveEmergencyRoutePage> 
    with TickerProviderStateMixin {
  late Stream<Map<String, dynamic>?> _requestStream;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  RealtimeChannel? _realtimeSubscription;
  
  // Local state for immediate UI updates
  Map<String, dynamic>? _currentRequestData;
  bool _mechanicRemoved = false;
  
  // Dynamic user location based on database coordinates
  LatLng? _actualUserLocation;
  
  // Route data for displaying actual driving routes
  List<List<LatLng>> _routes = [];
  double? _distanceInMeters;
  bool _isLoadingRoute = false;
  
  // Sheet height constraints
  static const double _minSheetHeight = 0.16; // 1/6 of screen
  static const double _maxSheetHeight = 0.5;  // 1/2 of screen
  static const double _initialSheetHeight = 0.3; // Initial height

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🚀 ActiveEmergencyRoutePage opened for requestId=${widget.requestId}');
    debugPrint('🚀 Initial userLocation = ${widget.userLocation}');
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
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
        
        // Extract user location from database coordinates
        final latStr = row['lat']?.toString();
        final lngStr = row['lng']?.toString();
        if (latStr != null && lngStr != null) {
          final lat = double.tryParse(latStr);
          final lng = double.tryParse(lngStr);
          if (lat != null && lng != null) {
            _actualUserLocation = LatLng(lat, lng);
            debugPrint('📍 Updated user location from DB: $_actualUserLocation');
          }
        }
        
        return row;
      }
      return null;
    });

    // Setup real-time subscription for immediate updates
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    debugPrint('🔄 Setting up real-time subscription for request ${widget.requestId}');
    
    _realtimeSubscription = Supabase.instance.client
        .channel('public:requests:${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (payload) {
            debugPrint('🔄 Real-time update received: ${payload.newRecord}');
            final newRecord = payload.newRecord;
            final status = newRecord['status']?.toString().toLowerCase().trim() ?? '';
            final mechanicId = newRecord['mechanic_id'];
            
            // Update user location from real-time data
            final latStr = newRecord['lat']?.toString();
            final lngStr = newRecord['lng']?.toString();
            if (latStr != null && lngStr != null) {
              final lat = double.tryParse(latStr);
              final lng = double.tryParse(lngStr);
              if (lat != null && lng != null) {
                _actualUserLocation = LatLng(lat, lng);
                debugPrint('📍 Updated user location from real-time: $_actualUserLocation');
              }
            }
            
            debugPrint('🔄 Real-time status update: $status, mechanic_id: $mechanicId');
            
            if (status == 'pending' && mechanicId == null) {
              debugPrint('✅ Mechanic removed - request back to pending status');
              // Clear routes when mechanic is removed
              if (mounted) {
                setState(() {
                  _mechanicRemoved = true;
                  _currentRequestData = Map<String, dynamic>.from(newRecord);
                  _routes.clear();
                  _distanceInMeters = null;
                  _isLoadingRoute = false;
                });
              }
            } else if (status == 'accepted' && mechanicId != null) {
              debugPrint('✅ New mechanic assigned - resetting removal flag');
              // New mechanic assigned, reset the removal flag and clear old routes
              if (mounted) {
                setState(() {
                  _mechanicRemoved = false;
                  _currentRequestData = Map<String, dynamic>.from(newRecord);
                  _routes.clear();
                  _distanceInMeters = null;
                  _isLoadingRoute = false;
                });
              }
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('📡 Subscription status: $status');
          if (error != null) {
            debugPrint('❌ Subscription error: $error');
          }
        });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _realtimeSubscription?.unsubscribe();
    super.dispose();
  }

  // Fetch actual driving routes using Mapbox Directions API
  Future<void> _fetchRoutes(LatLng start, LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });

    final accessToken = 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ';
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
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

        List<List<LatLng>> parsedRoutes = [];
        double? minDistance;

        for (var route in routes) {
          final coords = route['geometry']['coordinates'] as List;
          final points = coords
              .map((c) => LatLng(c[1] as double, c[0] as double))
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

        debugPrint('✅ Routes fetched: ${parsedRoutes.length} routes, shortest: ${(minDistance! / 1000).toStringAsFixed(1)} km');
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

  // Modern animated marker widget with app color scheme
  Widget _buildAnimatedMarker({
    required Color color,
    required IconData icon,
    bool animate = false,
    bool isEmergency = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = animate ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              gradient: isEmergency 
                ? RadialGradient(
                    colors: [
                      AppColors.danger,
                      AppColors.danger.withOpacity(0.8),
                    ],
                  )
                : RadialGradient(
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isEmergency 
                    ? AppColors.danger.withOpacity(0.6)
                    : color.withOpacity(0.5),
                  spreadRadius: animate ? 4 : 2,
                  blurRadius: animate ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
                if (animate)
                  BoxShadow(
                    color: isEmergency 
                      ? AppColors.danger.withOpacity(0.3)
                      : color.withOpacity(0.3),
                    spreadRadius: 8,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    // Show confirmation dialog
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.danger,
                AppColors.danger.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Cancel Request',
                style: AppTextStyles.heading.copyWith(
                  color: Colors.white,
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        titlePadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Are you sure you want to cancel this emergency request? This action cannot be undone.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontFamily: AppFonts.secondaryFont,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      'No, Keep Request',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.danger,
                          AppColors.danger.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Yes, Cancel',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        actionsPadding: EdgeInsets.zero,
      ),
    );

    // If user confirmed cancellation
    if (shouldCancel == true) {
      try {
        await Supabase.instance.client
            .from('requests')
            .update({'status': 'canceled'})
            .eq('id', widget.requestId);

        if (mounted) {
          // Navigate back to user home page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => UserHomePage()),
            (Route<dynamic> route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Request has been canceled'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel request: ${e.toString()}'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeMechanic() async {
    try {
      debugPrint('🗑️ Removing mechanic - updating request to pending status...');
      
      // Get the current mechanic ID before removing
      final currentRequest = await Supabase.instance.client
          .from('requests')
          .select('mechanic_id')
          .eq('id', widget.requestId)
          .single();
      
      final mechanicId = currentRequest['mechanic_id'];
      
      // Immediately update local state to show waiting UI
      setState(() {
        _mechanicRemoved = true;
        _currentRequestData = {
          ...(_currentRequestData ?? {}),
          'status': 'pending',
          'mechanic_id': null,
          'mech_lat': null,
          'mech_lng': null,
          // Preserve user location coordinates
          'lat': _actualUserLocation?.latitude.toString() ?? _currentRequestData?['lat'],
          'lng': _actualUserLocation?.longitude.toString() ?? _currentRequestData?['lng'],
        };
      });
      
      // Update request to remove mechanic and reset to pending status
      final updateResult = await Supabase.instance.client
          .from('requests')
          .update({
            'status': 'pending',
            'mechanic_id': null,
            'mech_lat': null,
            'mech_lng': null,
          })
          .eq('id', widget.requestId)
          .select();

      debugPrint('✅ Mechanic removal update completed: $updateResult');
      
      // Add the fired mechanic to ignored_requests table so they don't see this request again
      if (mechanicId != null) {
        try {
          await Supabase.instance.client
              .from('ignored_requests')
              .insert({
                'mechanic_id': mechanicId,
                'request_id': widget.requestId,
                'ignored_at': DateTime.now().toIso8601String(),
              });
          debugPrint('✅ Added fired mechanic $mechanicId to ignored_requests for request ${widget.requestId}');
        } catch (ignoreError) {
          // Log but don't fail the main operation if this fails
          debugPrint('⚠️ Failed to add mechanic to ignored_requests: $ignoreError');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mechanic removed. Searching for new mechanics...'),
            backgroundColor: AppColors.tealPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing mechanic: $e');
      
      // Revert local state if update failed
      setState(() {
        _mechanicRemoved = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove mechanic: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // Modern service complete popup with app styling
  void _showServiceCompleteDialog(Map<String, dynamic> request) {
    double rating = 0;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.tealPrimary,
                    AppColors.tealSecondary,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star_rate,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rate the Service',
                    style: AppTextStyles.heading.copyWith(
                      color: Colors.white,
                      fontFamily: AppFonts.primaryFont,
                    ),
                  ),
                ],
              ),
            ),
            titlePadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'How was your experience?',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            rating = index + 1.0;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: index < rating 
                              ? Colors.amber.shade400
                              : Colors.grey.shade300,
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Review text field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.tealPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: reviewController,
                      minLines: 3,
                      maxLines: 4,
                      style: AppTextStyles.body.copyWith(
                        fontFamily: AppFonts.secondaryFont,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Write a review (optional)',
                        labelStyle: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
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
                        child: ElevatedButton(
                          onPressed: () async {
                            if (rating == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please give a rating'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
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
                                  SnackBar(
                                    content: const Text('Thank you for your feedback!'),
                                    backgroundColor: AppColors.tealPrimary,
                                    duration: const Duration(seconds: 2),
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
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Submit Review',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            actionsPadding: EdgeInsets.zero,
          );
        });
      },
    );
  }


  Widget _buildFullScreenMap({
    required LatLng userPos,
    LatLng? mechPos,
  }) {
    // Fetch routes when mechanic position is available and routes are not yet loaded
    if (mechPos != null && _routes.isEmpty && !_isLoadingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchRoutes(userPos, mechPos);
      });
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: mechPos != null 
          ? LatLng(
              (userPos.latitude + mechPos.latitude) / 2,
              (userPos.longitude + mechPos.longitude) / 2,
            )
          : userPos,
        initialZoom: mechPos != null ? 14.5 : 15,
      ),
      children: [
        TileLayer(
          urlTemplate:
              "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ",
          additionalOptions: {
            'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ',
            'id': 'mapbox.mapbox-traffic-v1',
          },
        ),
        // Display actual driving routes instead of straight lines
        for (int i = 0; i < _routes.length; i++)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routes[i],
                color: i == 0 
                  ? AppColors.tealPrimary // Primary route
                  : AppColors.tealPrimary.withOpacity(0.6), // Alternative routes
                strokeWidth: i == 0 ? 6 : 4,
                borderColor: Colors.white,
                borderStrokeWidth: i == 0 ? 2 : 1,
              ),
            ],
          ),
        MarkerLayer(markers: [
          Marker(
            point: userPos,
            width: 40,
            height: 40,
            child: _buildAnimatedMarker(
              color: AppColors.danger,
              icon: Icons.person_pin_circle,
              animate: true,
              isEmergency: true,
            ),
          ),
          if (mechPos != null)
            Marker(
              point: mechPos,
              width: 40,
              height: 40,
              child: _buildAnimatedMarker(
                color: AppColors.tealPrimary,
                icon: Icons.build_circle,
                animate: false,
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildDraggableBottomSheet({
    Map<String, dynamic>? request,
    Map<String, dynamic>? mechanic,
    bool isWaiting = false,
  }) {
    return DraggableScrollableSheet(
      key: ValueKey('bottom_sheet_${isWaiting ? 'waiting' : 'ready'}'),
      initialChildSize: _initialSheetHeight,
      minChildSize: _minSheetHeight,
      maxChildSize: _maxSheetHeight,
      snap: true,
      snapSizes: [_minSheetHeight, _initialSheetHeight, _maxSheetHeight],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isWaiting 
                      ? _buildWaitingContent()
                      : _buildMechanicContent(mechanic!, request!),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitingContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Loading indicator with app colors
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.background,
                AppColors.background.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.tealPrimary,
                      AppColors.tealSecondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealPrimary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "🔍 Searching for mechanics nearby...",
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontFamily: AppFonts.primaryFont,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Emergency assistance is on the way",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: AppFonts.secondaryFont,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Cancel request button - always available when waiting
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.danger,
                AppColors.danger.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: Text(
              'Cancel Request',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _cancelRequest,
          ),
        ),
        
        const SizedBox(height: 80), // Extra space for smaller sheet size
      ],
    );
  }

  Widget _buildMechanicContent(Map<String, dynamic> mechanic, Map<String, dynamic> request) {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildMechanicCard(mechanic),
        const SizedBox(height: 24),
        
        // Action buttons
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.danger,
                      AppColors.danger.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: Text(
                    'Cancel Request',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _cancelRequest,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.tealPrimary,
                      AppColors.tealSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'Service Complete',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _showServiceCompleteDialog(request),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 80), // Extra space for scrolling
      ],
    );
  }

  Widget _buildMechanicCard(Map mechanic) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          BoxShadow(
            color: AppColors.tealPrimary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.tealPrimary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
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
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: (mechanic['image_url'] != null &&
                      mechanic['image_url'].toString().isNotEmpty)
                      ? NetworkImage(mechanic['image_url'])
                      : null,
                  backgroundColor: Colors.transparent,
                  child: (mechanic['image_url'] == null || 
                          mechanic['image_url'].toString().isEmpty)
                      ? Icon(
                          Icons.person,
                          color: AppColors.tealPrimary,
                          size: 32,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mechanic['full_name'] ?? 'Mechanic',
                      style: AppTextStyles.heading.copyWith(
                        fontFamily: AppFonts.primaryFont,
                        color: AppColors.primary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${mechanic['rating'] ?? 'N/A'}",
                            style: AppTextStyles.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          color: AppColors.tealPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mechanic['phone'] ?? 'No phone',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            fontFamily: AppFonts.secondaryFont,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (mechanic['expertise'] as List? ?? [])
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.tealPrimary.withOpacity(0.1),
                                      AppColors.tealSecondary.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.tealPrimary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.tealPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Cross button positioned at top right
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                // Show confirmation dialog for removing mechanic
                final bool? shouldRemove = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary,
                            AppColors.secondary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remove Mechanic',
                            style: AppTextStyles.heading.copyWith(
                              color: Colors.white,
                              fontFamily: AppFonts.primaryFont,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    titlePadding: EdgeInsets.zero,
                    content: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Are you sure you want to remove this mechanic? Your request will be set back to pending status and will be available for other mechanics.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontFamily: AppFonts.secondaryFont,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    actions: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppColors.textSecondary.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'No, Keep Mechanic',
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.secondary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    'Yes, Remove',
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    actionsPadding: EdgeInsets.zero,
                  ),
                );

                // If user confirmed removal
                if (shouldRemove == true) {
                  await _removeMechanic();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
          const SizedBox(height: 20),
          // Action buttons with modern styling
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.call,
                  label: "Call",
                  color: AppColors.secondary,
                  onPressed: () {
                    if (mechanic['phone'] != null) {
                      launchUrl(Uri.parse('tel:${mechanic['phone']}'));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble,
                  label: "Chat",
                  color: AppColors.tealPrimary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Chat feature coming soon!'),
                        backgroundColor: AppColors.tealPrimary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.person,
                  label: "Profile",
                  color: AppColors.primary,
                  onPressed: () => _showMechanicProfile(mechanic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showMechanicProfile(Map mechanic) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.gradientStart,
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Text(
            mechanic['full_name'] ?? 'Mechanic Profile',
            style: AppTextStyles.heading.copyWith(
              color: Colors.white,
              fontFamily: AppFonts.primaryFont,
            ),
          ),
        ),
        titlePadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildProfileItem(
              icon: Icons.phone,
              label: 'Phone',
              value: mechanic['phone'] ?? 'Not available',
            ),
            const SizedBox(height: 12),
            _buildProfileItem(
              icon: Icons.star,
              label: 'Rating',
              value: '${mechanic['rating'] ?? 'No rating'} ⭐',
            ),
            const SizedBox(height: 12),
            _buildProfileItem(
              icon: Icons.build,
              label: 'Expertise',
              value: (mechanic['expertise'] as List?)?.join(", ") ?? "General repair",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.tealPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.tealPrimary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Emergency Request Status',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _requestStream,
          builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Use actual user location if available, otherwise fallback to constructor location
            final loadingUserPos = _actualUserLocation ?? widget.userLocation;
            debugPrint('📍 Loading state using user position: $loadingUserPos');
            
            return Stack(
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
                                AppColors.primary.withOpacity(0.1),
                                AppColors.primary.withOpacity(0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildFullScreenMap(userPos: loadingUserPos),
                _buildDraggableBottomSheet(isWaiting: true),
              ],
            );
          }

          var request = snapshot.data;
          
          // Use local state if mechanic was just removed
          if (_mechanicRemoved && _currentRequestData != null) {
            request = _currentRequestData;
            debugPrint('🔄 Using local state due to mechanic removal');
          }
          
          // Store current request data for local state management
          if (request != null && !_mechanicRemoved) {
            _currentRequestData = request;
          }
          
          // Handle no request data
          if (request == null) {
            // Use actual user location if available, otherwise fallback to constructor location
            final noDataUserPos = _actualUserLocation ?? widget.userLocation;
            debugPrint('📍 No data state using user position: $noDataUserPos');
            
            return Stack(
              children: [
                _buildFullScreenMap(userPos: noDataUserPos),
                _buildDraggableBottomSheet(isWaiting: true),
              ],
            );
          }

          final status = request['status']?.toString().toLowerCase().trim() ?? '';
          debugPrint('🔄 Current request status: $status');
          debugPrint('🔄 Mechanic ID: ${request['mechanic_id']}');
          debugPrint('🔄 Mechanic removed flag: $_mechanicRemoved');
          
          // Handle pending/non-accepted requests OR when mechanic was just removed
          if (status != 'accepted' ||
              request['mechanic_id'] == null ||
              request['mech_lat'] == null ||
              request['mech_lng'] == null ||
              _mechanicRemoved) {
            debugPrint('🔄 Showing waiting UI - Status: $status, Removed: $_mechanicRemoved');
            
            // Use actual user location from database for waiting state too
            final waitingUserLat = _actualUserLocation?.latitude ?? 
                double.tryParse(request['lat']?.toString() ?? '') ??
                widget.userLocation.latitude;
            final waitingUserLng = _actualUserLocation?.longitude ?? 
                double.tryParse(request['lng']?.toString() ?? '') ??
                widget.userLocation.longitude;
            final waitingUserPos = LatLng(waitingUserLat, waitingUserLng);
            
            debugPrint('📍 Waiting state using user position: $waitingUserPos');
            
            return Stack(
              children: [
                _buildFullScreenMap(userPos: waitingUserPos),
                _buildDraggableBottomSheet(isWaiting: true),
              ],
            );
          }

          // Parse coordinates - use database coordinates for user location
          final userLat = _actualUserLocation?.latitude ?? 
              double.tryParse(request['lat']?.toString() ?? '') ??
              widget.userLocation.latitude;
          final userLng = _actualUserLocation?.longitude ?? 
              double.tryParse(request['lng']?.toString() ?? '') ??
              widget.userLocation.longitude;
          final mechLat = double.tryParse(request['mech_lat']?.toString() ?? '0') ?? 0.0;
          final mechLng = double.tryParse(request['mech_lng']?.toString() ?? '0') ?? 0.0;

          final userCurrentPos = LatLng(userLat, userLng);
          final mechanicPos = LatLng(mechLat, mechLng);
          
          debugPrint('📍 Using user position: $userCurrentPos (from ${_actualUserLocation != null ? 'cached' : 'database'})');
          debugPrint('📍 Using mechanic position: $mechanicPos');

          // Handle accepted request with mechanic
          return FutureBuilder<Map<String, dynamic>?>(
            future: _fetchMechanicProfile(request['mechanic_id'].toString()),
            builder: (context, mechanicSnap) {
              // Show map with mechanic position while loading profile
              if (mechanicSnap.connectionState == ConnectionState.waiting) {
                return Stack(
                  children: [
                    _buildFullScreenMap(
                      userPos: userCurrentPos,
                      mechPos: mechanicPos,
                    ),
                    _buildDraggableBottomSheet(isWaiting: true),
                    // Distance and route loading indicator
                    _buildRouteInfoOverlay(),
                  ],
                );
              }
              
              // Show map with mechanic but waiting drawer if no profile data
              if (!mechanicSnap.hasData || mechanicSnap.data == null) {
                return Stack(
                  children: [
                    _buildFullScreenMap(
                      userPos: userCurrentPos,
                      mechPos: mechanicPos,
                    ),
                    _buildDraggableBottomSheet(isWaiting: true),
                    // Distance and route loading indicator
                    _buildRouteInfoOverlay(),
                  ],
                );
              }
              
              // Show full UI with mechanic data
              return Stack(
                children: [
                  _buildFullScreenMap(
                    userPos: userCurrentPos,
                    mechPos: mechanicPos,
                  ),
                  _buildDraggableBottomSheet(
                    request: request,
                    mechanic: mechanicSnap.data!,
                    isWaiting: false,
                  ),
                  // Distance and route loading indicator
                  _buildRouteInfoOverlay(),
                ],
              );
            },
          );
        },
      ),
    ));
  }

  // Route information overlay widget
  Widget _buildRouteInfoOverlay() {
    return Positioned(
      top: 100,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distance indicator
          if (_distanceInMeters != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          
          const SizedBox(height: 8),
          
          // Loading indicator for route fetching
          if (_isLoadingRoute)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
        ],
      ),
    );
  }
}
