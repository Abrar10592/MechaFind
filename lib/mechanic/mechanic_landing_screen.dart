import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/widgets/direction_popup.dart';
import 'package:mechfind/widgets/sos_card.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:async';

class MechanicLandingScreen extends StatefulWidget {
  const MechanicLandingScreen({super.key});

  @override
  State<MechanicLandingScreen> createState() => _MechanicLandingScreenState();
}

class _MechanicLandingScreenState extends State<MechanicLandingScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final Location _locationController = Location();
  final SupabaseClient supabase = Supabase.instance.client;
  LatLng? _currentPosition;
  bool _hasListenerAttached = false;
  List<Map<String, dynamic>> _sosRequests = [];
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String _completedToday = '0';
  String _activeRequests = '0';
  String _rating = '0.0';
  String? _errorMessage;
  RealtimeChannel? _subscription;
  Timer? _debounceTimer;
  Timer? _locationUpdateTimer;
  String? _acceptedRequestId;
  LatLng? _lastUpdatedPosition;
  Map<String, dynamic>? _activeRequest; // Store active request details for bubble
  bool _isModalMinimized = false; // Track if modal is minimized to bubble

  // Animation controllers
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
    
    // Initialize animations
    _initAnimations();
    
    _initLocationSetup();
    // Don't call _fetchMechanicData() here - it will be called after location is ready
    _setupRealtimeSubscription();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.unsubscribe();
    _debounceTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _locationController.onLocationChanged.drain();
    
    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('App resumed, reinitializing location setup');
      _initLocationSetup();
    }
  }

  Future<void> _initLocationSetup() async {
    print('Initializing location setup...');
    bool serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      print('Location service disabled, requesting...');
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Please enable location services to receive nearby requests';
          _isLoading = false;
          _isInitialLoad = false;
        });
        print('Location service still disabled');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location services are required to show nearby requests'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _initLocationSetup(),
            ),
          ),
        );
        return;
      }
    }
    print('Location service enabled');

    PermissionStatus permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      print('Location permission denied, requesting...');
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() {
          _errorMessage = 'Location permission is required to show nearby requests';
          _isLoading = false;
          _isInitialLoad = false;
        });
        print('Location permission status: $permissionGranted');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is required to show nearby requests'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _initLocationSetup(),
            ),
          ),
        );
        return;
      }
    }
    print('Location permission granted');

    try {
      final locationData = await _locationController.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location access timed out');
        },
      );
      if (locationData.latitude != null && locationData.longitude != null) {
        final newPosition = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _errorMessage = null; // Clear any previous errors
          });
          print('One-time location fetched: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
          
          // Now that we have location, fetch mechanic data with distance filtering
          _fetchMechanicData();
        }
      } else {
        print('Invalid one-time location data: $locationData');
        if (mounted) {
          setState(() {
            _errorMessage = 'Unable to get precise location';
          });
        }
      }
    } catch (e) {
      print('Error fetching one-time location: $e');
      String userFriendlyError;
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        userFriendlyError = 'Location access is taking longer than usual. Please check your GPS signal.';
      } else if (e.toString().contains('permission') || e.toString().contains('denied')) {
        userFriendlyError = 'Location permission is required to show nearby requests.';
      } else if (e.toString().contains('service') || e.toString().contains('disabled')) {
        userFriendlyError = 'Please enable location services in your device settings.';
      } else {
        userFriendlyError = 'Unable to access location. The app will continue with limited functionality.';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyError;
          _isLoading = false;
          _isInitialLoad = false;
        });
        
        // Only show snackbar for critical errors, not timeouts
        if (!e.toString().contains('timeout')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFriendlyError),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _initLocationSetup(),
              ),
            ),
          );
        }
      }
    }

    if (!_hasListenerAttached) {
      print('Setting up location listener...');
      _locationController.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          final newPosition = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          if (mounted && (_currentPosition == null || _isSignificantChange(newPosition, _currentPosition!))) {
            setState(() {
              _currentPosition = newPosition;
            });
            print('Location updated: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
            
            // Refetch data when location changes significantly
            _fetchMechanicData();
          }
        } else {
          print('Invalid location data from stream: $locationData');
        }
      });
      _hasListenerAttached = true;
    }
    print('Current position after setup: $_currentPosition');
  }

  bool _isSignificantChange(LatLng newPosition, LatLng oldPosition) {
    const double threshold = 0.0001; // ~10 meters
    return (newPosition.latitude - oldPosition.latitude).abs() > threshold ||
        (newPosition.longitude - oldPosition.longitude).abs() > threshold;
  }

  Future<void> _updateMechanicLocation(String requestId, LatLng position) async {
    if (requestId.isEmpty) {
      print('Error: Cannot update location - requestId is empty');
      return;
    }
    
    try {
      final updateData = {
        'mech_lat': position.latitude.toString(),
        'mech_lng': position.longitude.toString(),
      };
      
      print('🔄 Updating mechanic location for request $requestId: $updateData');
      
      await supabase
          .from('requests')
          .update(updateData)
          .eq('id', requestId);
      print('✅ Mechanic location updated for request $requestId: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error updating mechanic location for request $requestId: $e');
      // Don't show error to user for location updates as it's background operation
      // Only log the error for debugging
    }
  }

  void _startLocationUpdateTimer(String requestId) {
    _locationUpdateTimer?.cancel(); // Cancel any existing timer
    _acceptedRequestId = requestId;
    _lastUpdatedPosition = _currentPosition;
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_acceptedRequestId == null || _acceptedRequestId!.isEmpty || !mounted) {
        timer.cancel();
        print('Location update timer canceled: No active request or widget disposed');
        return;
      }
      // Check if the request is still active
      final request = await supabase
          .from('requests')
          .select('status')
          .eq('id', _acceptedRequestId!)
          .single();
      if (request['status'] != 'accepted') {
        timer.cancel();
        _acceptedRequestId = null;
        _lastUpdatedPosition = null;
        setState(() {
          _activeRequest = null;
          _isModalMinimized = false;
        });
        print('Location update timer canceled: Request status is ${request['status']}');
        return;
      }
      if (_currentPosition != null && _lastUpdatedPosition != null) {
        if (_isSignificantChange(_currentPosition!, _lastUpdatedPosition!)) {
          await _updateMechanicLocation(_acceptedRequestId!, _currentPosition!);
          _lastUpdatedPosition = _currentPosition;
        } else {
          print('No significant location change for request $_acceptedRequestId');
        }
      } else if (_currentPosition != null) {
        await _updateMechanicLocation(_acceptedRequestId!, _currentPosition!);
        _lastUpdatedPosition = _currentPosition;
      } else {
        print('No current position available for request $_acceptedRequestId');
      }
    });
    print('Started location update timer for request $requestId');
  }

  Future<void> _fetchMechanicData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not logged in';
        _isLoading = false;
      });
      print('Error: User not logged in');
      return;
    }

    setState(() {
      if (_isInitialLoad) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final completedResponse = await supabase
          .from('requests')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String())
          .count();

      print('Completed today count: ${completedResponse.count}');

      // First, let's check if there are any pending requests at all (this might be blocked by RLS)
      try {
        final allPendingResponse = await supabase
            .from('requests')
            .select('id, status, mechanic_id')
            .eq('status', 'pending');
        
        print('🔍 ALL pending requests in database: ${allPendingResponse.length}');
        print('🔍 Sample pending requests: $allPendingResponse');
      } catch (e) {
        print('❌ Error fetching all pending requests (likely RLS issue): $e');
      }

      // Try to fetch requests without RLS restrictions by using a more permissive query
      final pendingResponse = await supabase
          .from('requests')
          .select('id, user_id, guest_id, vehicle, description, image, lat, lng, request_type, users!left(full_name, phone, image_url)')
          .eq('status', 'pending')
          .eq('request_type', 'emergency')
          .filter('mechanic_id', 'is', null);

      print('🔍 Pending response after mechanic_id filter: ${pendingResponse.length}');
      print('🔍 Pending response raw: $pendingResponse');

      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', user.id);

      print('Reviews fetched: ${reviewsResponse.length}');

      // Fetch ignored requests for this mechanic
      final ignoredResponse = await supabase
          .from('ignored_requests')
          .select('request_id')
          .eq('mechanic_id', user.id);

      final ignoredRequestIds = ignoredResponse.map((item) => item['request_id'].toString()).toSet();
      print('📋 Ignored requests for mechanic ${user.id}: ${ignoredRequestIds.length} requests');
      print('📋 Ignored request IDs: $ignoredRequestIds');

      List<Map<String, dynamic>> filteredRequests = [];
      const double maxDistanceKm = 10.0;
      final latlng.Distance distanceCalc = const latlng.Distance();
      
      // Convert _currentPosition to latlng.LatLng for distance calculation
      latlng.LatLng? currentLatLng;
      if (_currentPosition != null) {
        currentLatLng = latlng.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        print('🔄 Current position converted: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
      } else {
        print('❌ _currentPosition is null - this will prevent any requests from being shown');
        // If we have no location, show an error and return
        setState(() {
          _errorMessage = 'Location required to show nearby requests';
          _isLoading = false;
        });
        return;
      }
      
      print('🔍 Processing ${pendingResponse.length} requests for distance filtering...');
      
      for (var request in pendingResponse) {
        print('🔍 Processing request: ${request['id']}');
        
        // Skip ignored requests
        if (ignoredRequestIds.contains(request['id'].toString())) {
          print('🚫 Request ${request['id']} SKIPPED (ignored by mechanic)');
          continue;
        }
        
        print('🔍 Request data: $request');
        final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
        
        print('🎯 Parsed coordinates: lat=$lat, lng=$lng');
        print('🎯 Validation check: lat != 0.0 = ${lat != 0.0}, lng != 0.0 = ${lng != 0.0}');
        
        // Calculate distance between mechanic and SOS request using the same logic as mechanic_map
        if (lat != 0.0 && lng != 0.0) {
          final point = latlng.LatLng(lat, lng);
          final distance = distanceCalc.as(
            latlng.LengthUnit.Kilometer,
            currentLatLng,
            point,
          );
          
          print('Request ${request['id']}: Distance = ${distance.toStringAsFixed(2)} km');
          
          // Only add requests within 10 km radius
          if (distance <= maxDistanceKm) {
            print('✅ Request ${request['id']} ADDED (within ${maxDistanceKm}km)');
            
            // Handle both guest and authenticated user requests
            Map<String, dynamic> processedRequest = {
              'id': request['id'],
              'vehicle': request['vehicle'],
              'description': request['description'],
              'image': request['image'],
              'lat': lat, // Use parsed double values
              'lng': lng, // Use parsed double values
              'request_type': request['request_type'] ?? 'normal',
              'distance': distance,
            };
            
            // Check if it's a guest request or authenticated user request
            if (request['user_id'] != null) {
              // Authenticated user request
              processedRequest['user_id'] = request['user_id'];
              processedRequest['guest_id'] = null;
              final fullName = request['users']?['full_name'];
              final phone = request['users']?['phone'];
              final imageUrl = request['users']?['image_url'];
              
              processedRequest['user_name'] = fullName ?? 'Unknown User';
              processedRequest['phone'] = phone ?? 'N/A';
              processedRequest['image_url'] = imageUrl;
              
              print('✅ Authenticated user request:');
              print('   - full_name: $fullName');
              print('   - phone: $phone');
              print('   - image_url: $imageUrl');
              print('   - final user_name: ${processedRequest['user_name']}');
            } else if (request['guest_id'] != null) {
              // Guest request
              processedRequest['user_id'] = null;
              processedRequest['guest_id'] = request['guest_id'];
              processedRequest['user_name'] = 'Guest User';
              processedRequest['phone'] = 'Contact via app';
              processedRequest['image_url'] = null;
              print('✅ Guest request: Guest User (guest_id: ${request['guest_id']})');
            } else {
              // Invalid request - skip
              print('❌ Request ${request['id']} SKIPPED (no user_id or guest_id)');
              continue;
            }
            
            print('🔍 Final processed request data: $processedRequest');
            
            filteredRequests.add(processedRequest);
          } else {
            print('❌ Request ${request['id']} REJECTED (${distance.toStringAsFixed(2)}km > ${maxDistanceKm}km)');
          }
        } else {
          print('❌ Request ${request['id']} REJECTED (invalid location data)');
        }
        // If location data is missing, don't show the request
      }

      print('📊 Distance Filtering Summary:');
      print('   Total requests from database: ${pendingResponse.length}');
      print('   Ignored requests: ${ignoredRequestIds.length}');
      print('   Filtered requests (within ${maxDistanceKm}km and not ignored): ${filteredRequests.length}');
      print('   Current mechanic location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      print('📊 Filtered requests details: $filteredRequests');

      double totalRating = 0.0;
      int reviewCount = reviewsResponse.length;
      for (var review in reviewsResponse) {
        totalRating += (review['rating'] as num).toDouble();
      }
      final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

      setState(() {
        _completedToday = completedResponse.count.toString();
        _activeRequests = filteredRequests.length.toString();
        _rating = averageRating.toStringAsFixed(1);
        _sosRequests = filteredRequests;
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
        _isInitialLoad = false;
      });
      print('Error fetching data: $e');
    }
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('Cannot set up subscription: User not logged in');
      return;
    }

    _subscription = supabase
        .channel('public:requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'pending',
          ),
          callback: (payload) {
            print('Realtime event: ${payload.eventType}, Payload: $payload');
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              _fetchMechanicData();
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'mechanic_id',
            value: user.id,
          ),
          callback: (payload) {
            print('Realtime event for mechanic requests: ${payload.eventType}, Payload: $payload');
            if (payload.newRecord['status'] == 'completed' || payload.newRecord['status'] == 'canceled') {
              _locationUpdateTimer?.cancel();
              _acceptedRequestId = null;
              _lastUpdatedPosition = null;
              setState(() {
                _activeRequest = null;
                _isModalMinimized = false;
              });
              print('Cleared active request and stopped location updates for request ${payload.newRecord['id']} due to status: ${payload.newRecord['status']}');
            }
          },
        )
        .subscribe((status, [error]) {
          print('Subscription status: $status, Error: $error');
          if (status == 'SUBSCRIPTION_ERROR' && error != null) {
            // Don't show technical subscription errors to users
            // Just log them and continue with app functionality
            print('Subscription error occurred: $error');
            setState(() {
              _errorMessage = 'Connection issue. Some features may be limited.';
            });
          }
        });
  }

  Future<void> _acceptRequest(String requestId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to accept requests')),
      );
      print('Error: User not logged in during accept request');
      return;
    }

    // Check if mechanic already has an active request
    try {
      final existingActiveRequest = await supabase
          .from('requests')
          .select('id, status')
          .eq('mechanic_id', user.id)
          .eq('status', 'accepted')
          .maybeSingle();

      if (existingActiveRequest != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an active request. Please complete it first.'),
            backgroundColor: Colors.orange,
          ),
        );
        print('Mechanic ${user.id} already has active request: ${existingActiveRequest['id']}');
        return;
      }
    } catch (e) {
      print('Error checking for existing active requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to verify active requests. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final updateData = <String, dynamic>{
        'mechanic_id': user.id,
        'status': 'accepted',
      };
      if (_currentPosition != null) {
        updateData['mech_lat'] = _currentPosition!.latitude.toString();
        updateData['mech_lng'] = _currentPosition!.longitude.toString();
      } else {
        print('Warning: No current position available when accepting request $requestId');
      }

      print('🔄 Attempting to update request $requestId with data: $updateData');
      print('🔄 Current user ID: ${user.id}');
      
      final updateResponse = await supabase
          .from('requests')
          .update(updateData)
          .eq('id', requestId)
          .select();

      print('✅ Update response: $updateResponse');
      
      if (updateResponse.isEmpty) {
        throw Exception('No rows were updated. This might be due to RLS policy restrictions.');
      }

      // Store active request details
      final request = _sosRequests.firstWhere((req) => req['id'] == requestId);
      setState(() {
        _activeRequest = Map<String, dynamic>.from(request);
        _sosRequests.removeWhere((req) => req['id'] == requestId);
        _activeRequests = _sosRequests.length.toString();
        _isModalMinimized = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      print('Request $requestId accepted');

      if (_currentPosition != null) {
        _startLocationUpdateTimer(requestId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location tracking unavailable. Please ensure GPS is enabled.'),
            duration: Duration(seconds: 3),
          ),
        );
        print('Cannot start location update timer: No current position');
      }
    } catch (e) {
      print('❌ Error accepting request $requestId: $e');
      
      String errorMessage;
      if (e.toString().contains('row-level security') || e.toString().contains('RLS') || e.toString().contains('policy')) {
        errorMessage = 'Permission denied: Unable to update request. RLS policy issue detected.';
        print('🚨 RLS POLICY ERROR: Mechanic ${user.id} cannot update request $requestId due to Row Level Security policy restrictions');
      } else if (e.toString().contains('No rows were updated')) {
        errorMessage = 'Request could not be updated. This may be due to database security policies.';
        print('🚨 NO ROWS UPDATED: Possible RLS policy blocking update operation');
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('permission') || e.toString().contains('auth')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else {
        errorMessage = 'Unable to accept request. Please try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _acceptRequest(requestId),
          ),
        ),
      );
      print('Error accepting request $requestId: $e');
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await supabase
          .from('requests')
          .update({
            'status': 'pending',
            'mechanic_id': null,
            'mech_lat': null,
            'mech_lng': null,
          })
          .eq('id', requestId);

      setState(() {
        _sosRequests.removeWhere((request) => request['id'] == requestId);
        _activeRequests = _sosRequests.length.toString();
        _activeRequest = null;
        _isModalMinimized = false;
        _locationUpdateTimer?.cancel();
        _acceptedRequestId = null;
        _lastUpdatedPosition = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
      print('Request $requestId rejected');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e')),
      );
      print('Error rejecting request $requestId: $e');
    }
  }

  Future<void> _ignoreRequest(String requestId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to ignore requests')),
      );
      return;
    }

    try {
      // Store the ignored request in the database
      await supabase.from('ignored_requests').insert({
        'mechanic_id': user.id,
        'request_id': requestId,
        'ignored_at': DateTime.now().toIso8601String(),
      });

      // Remove from local UI
      setState(() {
        _sosRequests.removeWhere((request) => request['id'] == requestId);
        _activeRequests = _sosRequests.length.toString();
        _activeRequest = null;
        _isModalMinimized = false;
        _locationUpdateTimer?.cancel();
        _acceptedRequestId = null;
        _lastUpdatedPosition = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ignored permanently')),
      );
      print('Request $requestId ignored permanently by mechanic ${user.id}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ignoring request: $e')),
      );
      print('Error ignoring request $requestId: $e');
    }
  }

  void _showDirectionModal() {
    if (_activeRequest == null) return;
    
    print('🔍 Active request data in _showDirectionModal: $_activeRequest');
    
    // Safely extract values with proper null handling
    final userId = _activeRequest!['user_id']?.toString() ?? '';
    final guestId = _activeRequest!['guest_id']?.toString() ?? '';
    final effectiveUserId = userId.isNotEmpty ? userId : guestId;
    final requestId = _activeRequest!['id']?.toString() ?? '';
    final phone = _activeRequest!['phone']?.toString() ?? 'Contact via app';
    final userName = _activeRequest!['user_name']?.toString() ?? 'Unknown User';
    final imageUrl = _activeRequest!['image_url']?.toString() ?? '';
    
    print('🔍 Extracted values: userId=$userId, guestId=$guestId, effectiveUserId=$effectiveUserId');
    print('🔍 Other values: phone=$phone, userName=$userName, imageUrl=$imageUrl');
    
    // Validate required data
    if (requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid request data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.0,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.0, 0.95],
        builder: (context, scrollController) {
          return DirectionPopup(
            user_id: effectiveUserId,
            requestId: requestId,
            requestLocation: latlng.LatLng(
              _activeRequest!['lat'] ?? 0.0,
              _activeRequest!['lng'] ?? 0.0,
            ),
            phone: phone,
            name: userName,
            imageUrl: imageUrl,
            onReject: () => _rejectRequest(requestId),
            onMinimize: () {
              setState(() {
                _isModalMinimized = true;
              });
              Navigator.of(context).pop();
            },
          );
        },
      ),
    ).then((_) {
      // Modal dismissed without rejecting
      setState(() {
        _isModalMinimized = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;
    final isEnglish = currentLang == 'en';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
        child: SafeArea(
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
              
              // Main content
              _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState(isEnglish)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: CustomScrollView(
                              slivers: [
                                // App Bar
                                SliverAppBar(
                                  expandedHeight: 120,
                                  floating: false,
                                  pinned: true,
                                  elevation: 0,
                                  backgroundColor: Colors.transparent,
                                  flexibleSpace: FlexibleSpaceBar(
                                    background: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primary.withOpacity(0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(30),
                                          bottomRight: Radius.circular(30),
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Decorative circles
                                          Positioned(
                                            top: 20,
                                            right: 30,
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 40,
                                            right: 80,
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(0.15),
                                              ),
                                            ),
                                          ),
                                          // Title
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isEnglish ? "Welcome Back!" : "স্বাগতম!",
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.9),
                                                      fontSize: FontSizes.body,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isEnglish ? "Mechanic Dashboard" : "মেকানিক ড্যাশবোর্ড",
                                                    style: AppTextStyles.heading.copyWith(
                                                      color: Colors.white,
                                                      fontSize: FontSizes.heading,
                                                      fontFamily: AppFonts.primaryFont,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Content
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Stats Cards
                                        _buildStatsSection(isEnglish),
                                        
                                        const SizedBox(height: 30),
                                        
                                        // SOS Requests Section
                                        _buildSosSection(isEnglish),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              
              // Floating bubble for minimized modal
              if (_isModalMinimized && _activeRequest != null)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildFloatingBubble(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your dashboard...',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: FontSizes.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: FontSizes.body,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _initLocationSetup(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  isEnglish ? 'Retry' : 'পুনঃচেষ্টা',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEnglish ? "Your Performance" : "আপনার কার্যক্রম",
          style: AppTextStyles.heading.copyWith(
            fontSize: FontSizes.subHeading,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildEnhancedStatCard(
                _completedToday,
                isEnglish ? "Completed\nToday" : "আজ সম্পন্ন",
                Icons.check_circle_outline,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEnhancedStatCard(
                _activeRequests,
                isEnglish ? "Active\nRequests" : "সক্রিয়\nঅনুরোধ",
                Icons.pending_actions,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEnhancedStatCard(
                _rating,
                isEnglish ? "Your\nRating" : "আপনার\nরেটিং",
                Icons.assessment,
                Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(String number, String label, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.02,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  number,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 28,
                    color: color,
                    fontFamily: AppFonts.primaryFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    fontSize: FontSizes.caption,
                    fontFamily: AppFonts.secondaryFont,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSosSection(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEnglish ? "Emergency Requests" : "জরুরি অনুরোধসমূহ",
                style: AppTextStyles.heading.copyWith(
                  fontSize: FontSizes.subHeading,
                  fontFamily: AppFonts.primaryFont,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${_sosRequests.length}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: FontSizes.body,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _sosRequests.isEmpty
              ? _buildEmptyRequestsState(isEnglish)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sosRequests.length,
                  itemBuilder: (context, index) {
                    final request = _sosRequests[index];
                    print('Rendering SOS card: $request, current_location: $_currentPosition');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SosCard(
                        request: request,
                        current_location: _currentPosition,
                        onIgnore: () => _ignoreRequest(request['id']),
                        onAccept: () {
                          _acceptRequest(request['id']).then((_) {
                            _showDirectionModal();
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyRequestsState(bool isEnglish) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEnglish ? "No Active Requests" : "কোন সক্রিয় অনুরোধ নেই",
            style: AppTextStyles.heading.copyWith(
              fontSize: FontSizes.subHeading,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEnglish 
                ? "You're all caught up! New emergency\nrequests will appear here."
                : "আপনি সব কাজ শেষ করেছেন! নতুন জরুরি\nঅনুরোধ এখানে দেখা যাবে।",
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: FontSizes.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSosCard(Map<String, dynamic> request, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.red.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: (request['users']?['image_url'] != null)
                    ? NetworkImage(request['users']['image_url'])
                    : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['users']?['full_name'] ?? 'Unknown User',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body + 2,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      request['vehicle'] ?? 'Unknown Vehicle',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'URGENT',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _acceptRequest(request['id']).then((_) {
                      _showDirectionModal();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _ignoreRequest(request['id']),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
                child: Text(
                  'Ignore',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBubble() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _showDirectionModal,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.directions,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

}