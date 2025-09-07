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
  bool _isDirectionModalOpen = false; // Track if direction modal is currently open
  Timer? _activeRequestCheckTimer; // Timer to periodically verify active request
  int _unreadNotificationsCount = 0; // Track unread notifications count
  List<Map<String, dynamic>> _previousSosRequests = []; // Track previous requests to detect new ones

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
    _fetchUnreadNotificationsCount(); // Add this line
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
    _activeRequestCheckTimer?.cancel();
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
      _initLocationSetup();
    }
  }

  Future<void> _initLocationSetup() async {
    bool serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Please enable location services to receive nearby requests';
            _isLoading = false;
            _isInitialLoad = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are required to show nearby requests'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _initLocationSetup(),
              ),
            ),
          );
        }
        return;
      }
    }

    PermissionStatus permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Location permission is required to show nearby requests';
            _isLoading = false;
            _isInitialLoad = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is required to show nearby requests'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _initLocationSetup(),
              ),
            ),
          );
        }
        return;
      }
    }

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
          
          // Now that we have location, fetch mechanic data with distance filtering
          _fetchMechanicData();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Unable to get precise location';
          });
        }
      }
    } catch (e) {
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
            
            // Refetch data when location changes significantly
            _fetchMechanicData();
          }
        }
      });
      _hasListenerAttached = true;
    }
  }

  bool _isSignificantChange(LatLng newPosition, LatLng oldPosition) {
    const double threshold = 0.0001; // ~10 meters
    return (newPosition.latitude - oldPosition.latitude).abs() > threshold ||
        (newPosition.longitude - oldPosition.longitude).abs() > threshold;
  }

  Future<void> _updateMechanicLocation(String requestId, LatLng position) async {
    if (requestId.isEmpty) {
      return;
    }
    
    try {
      final updateData = {
        'mech_lat': position.latitude.toString(),
        'mech_lng': position.longitude.toString(),
      };
      
      await supabase
          .from('requests')
          .update(updateData)
          .eq('id', requestId);
    } catch (e) {
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
        return;
      }
      if (_currentPosition != null && _lastUpdatedPosition != null) {
        if (_isSignificantChange(_currentPosition!, _lastUpdatedPosition!)) {
          await _updateMechanicLocation(_acceptedRequestId!, _currentPosition!);
          _lastUpdatedPosition = _currentPosition;
        }
      } else if (_currentPosition != null) {
        await _updateMechanicLocation(_acceptedRequestId!, _currentPosition!);
        _lastUpdatedPosition = _currentPosition;
      }
    });
  }

  Future<void> _fetchMechanicData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not logged in';
        _isLoading = false;
      });
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

      // Try to fetch requests without RLS restrictions by using a more permissive query
      final pendingResponse = await supabase
          .from('requests')
          .select('id, user_id, guest_id, vehicle, description, image, lat, lng, request_type, users!left(full_name, phone, image_url)')
          .eq('status', 'pending')
          .eq('request_type', 'emergency')
          .filter('mechanic_id', 'is', null);

      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', user.id);

      // Fetch ignored requests for this mechanic
      final ignoredResponse = await supabase
          .from('ignored_requests')
          .select('request_id')
          .eq('mechanic_id', user.id);

      final ignoredRequestIds = ignoredResponse.map((item) => item['request_id'].toString()).toSet();

      List<Map<String, dynamic>> filteredRequests = [];
      const double maxDistanceKm = 10.0;
      final latlng.Distance distanceCalc = const latlng.Distance();
      
      // Convert _currentPosition to latlng.LatLng for distance calculation
      latlng.LatLng? currentLatLng;
      if (_currentPosition != null) {
        currentLatLng = latlng.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      } else {
        // If we have no location, show an error and return
        setState(() {
          _errorMessage = 'Location required to show nearby requests';
          _isLoading = false;
        });
        return;
      }
      
      for (var request in pendingResponse) {
        // Skip ignored requests
        if (ignoredRequestIds.contains(request['id'].toString())) {
          continue;
        }
        
        final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
        
        // Calculate distance between mechanic and SOS request using the same logic as mechanic_map
        if (lat != 0.0 && lng != 0.0) {
          final point = latlng.LatLng(lat, lng);
          final distance = distanceCalc.as(
            latlng.LengthUnit.Kilometer,
            currentLatLng,
            point,
          );
          
          // Only add requests within 10 km radius
          if (distance <= maxDistanceKm) {
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
            } else if (request['guest_id'] != null) {
              // Guest request
              processedRequest['user_id'] = null;
              processedRequest['guest_id'] = request['guest_id'];
              processedRequest['user_name'] = 'Guest User';
              processedRequest['phone'] = 'Contact via app';
              processedRequest['image_url'] = null;
            } else {
              // Invalid request - skip
              continue;
            }
            
            filteredRequests.add(processedRequest);
          }
        }
        // If location data is missing, don't show the request
      }

      double totalRating = 0.0;
      int reviewCount = reviewsResponse.length;
      for (var review in reviewsResponse) {
        totalRating += (review['rating'] as num).toDouble();
      }
      final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

      if (mounted) {
        // Check for new requests before updating state
        await _checkForNewRequestsAndNotify(filteredRequests);
        
        setState(() {
          _completedToday = completedResponse.count.toString();
          _activeRequests = filteredRequests.length.toString();
          _rating = averageRating.toStringAsFixed(1);
          _sosRequests = filteredRequests;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
      
      // Check for existing accepted requests for this mechanic
      await _checkForActiveRequest();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching data: $e';
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _checkForActiveRequest() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final activeRequestResponse = await supabase
          .from('requests')
          .select('id, user_id, guest_id, vehicle, description, image, lat, lng, request_type, users!left(full_name, phone, image_url)')
          .eq('mechanic_id', user.id)
          .eq('status', 'accepted')
          .eq('request_type', 'emergency')
          .maybeSingle();

      if (activeRequestResponse != null) {
        print('Found active accepted request: ${activeRequestResponse['id']}');
        
        // Process the request data similar to how it's done in _fetchMechanicData
        Map<String, dynamic> processedRequest = {
          'id': activeRequestResponse['id'],
          'vehicle': activeRequestResponse['vehicle'],
          'description': activeRequestResponse['description'],
          'image': activeRequestResponse['image'],
          'lat': activeRequestResponse['lat'],
          'lng': activeRequestResponse['lng'],
          'request_type': activeRequestResponse['request_type'] ?? 'emergency',
        };

        // Handle user data
        if (activeRequestResponse['users'] != null) {
          final userData = activeRequestResponse['users'];
          processedRequest['user_id'] = activeRequestResponse['user_id'];
          processedRequest['user_name'] = userData['full_name'] ?? 'Unknown User';
          processedRequest['phone'] = userData['phone'] ?? 'Contact via app';
          processedRequest['image_url'] = userData['image_url'] ?? '';
        } else if (activeRequestResponse['guest_id'] != null) {
          processedRequest['guest_id'] = activeRequestResponse['guest_id'];
          processedRequest['user_name'] = 'Guest User';
          processedRequest['phone'] = 'Contact via app';
          processedRequest['image_url'] = '';
        }

        if (mounted) {
          setState(() {
            _activeRequest = processedRequest;
          });
        }
        
        // Start periodic checking of active request
        _startActiveRequestMonitoring();
      } else {
        print('No active accepted requests found for mechanic ${user.id}');
        if (mounted) {
          setState(() {
            _activeRequest = null;
          });
        }
        _stopActiveRequestMonitoring();
      }
    } catch (e) {
      print('Error checking for active requests: $e');
    }
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) {
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
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              _fetchMechanicData();
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen to all events
          schema: 'public',
          table: 'requests',
          callback: (payload) {
            print('Realtime event received: ${payload.eventType}');
            print('Payload newRecord: ${payload.newRecord}');
            print('Payload oldRecord: ${payload.oldRecord}');
            
            // Handle specific cases for active request
            if (_activeRequest != null) {
              final activeRequestId = _activeRequest!['id']?.toString();
              final payloadRequestId = (payload.newRecord['id'] ?? payload.oldRecord['id'])?.toString();
              
              if (activeRequestId == payloadRequestId) {
                print('Event affects active request $activeRequestId');
                
                if (payload.eventType == PostgresChangeEvent.update) {
                  final newStatus = payload.newRecord['status'];
                  final newMechanicId = payload.newRecord['mechanic_id'];
                  final rejectionReason = payload.newRecord['rejection_reason'];
                  
                  print('Status changed to: $newStatus, Mechanic ID: $newMechanicId, Rejection Reason: $rejectionReason');
                  
                  // Clear active request if:
                  // 1. Status is completed or canceled
                  // 2. Request was "unclaimed" (mechanic_id set to null and status back to pending)
                  // 3. Request was assigned to a different mechanic
                  if (newStatus == 'completed' || 
                      newStatus == 'canceled' ||
                      (newStatus == 'pending' && newMechanicId == null) ||
                      (newMechanicId != null && newMechanicId != supabase.auth.currentUser?.id)) {
                    
                    // Don't show message if it was rejected by a mechanic
                    if (rejectionReason == 'mechanic_rejected') {
                      print('Request was rejected by mechanic, clearing silently');
                      _locationUpdateTimer?.cancel();
                      _acceptedRequestId = null;
                      _lastUpdatedPosition = null;
                      _stopActiveRequestMonitoring();
                      
                      if (mounted) {
                        setState(() {
                          _activeRequest = null;
                          _isModalMinimized = false;
                        });
                      }
                      return;
                    }
                    
                    String reason = 'Request status changed to $newStatus';
                    if (newStatus == 'pending' && newMechanicId == null) {
                      reason = 'Request was cancelled by the user';
                    } else if (newMechanicId != null && newMechanicId != supabase.auth.currentUser?.id) {
                      reason = 'Request was assigned to another mechanic';
                    }
                    
                    _clearActiveRequest(reason);
                  }
                }
              }
            }
            
            // Always refresh the pending requests list
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              _fetchMechanicData();
            });
          },
        )
        .subscribe((status, [error]) {
          if (status == 'SUBSCRIPTION_ERROR' && error != null) {
            print('Subscription error: $error');
            setState(() {
              _errorMessage = 'Connection issue. Some features may be limited.';
            });
          } else if (status == 'SUBSCRIBED') {
            print('Successfully subscribed to realtime changes');
          }
        });
  }

  void _clearActiveRequest(String reason) {
    print('Clearing active request: $reason');
    _locationUpdateTimer?.cancel();
    _acceptedRequestId = null;
    _lastUpdatedPosition = null;
    _stopActiveRequestMonitoring();
    
    if (mounted) {
      setState(() {
        _activeRequest = null;
        _isModalMinimized = false;
        _isDirectionModalOpen = false; // Reset direction modal flag
      });
      
      // Show user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startActiveRequestMonitoring() {
    print('Starting active request monitoring');
    _stopActiveRequestMonitoring(); // Stop any existing timer
    _activeRequestCheckTimer = Timer.periodic(
      const Duration(seconds: 5), // Check every 5 seconds
      (timer) => _verifyActiveRequest(),
    );
  }

  void _stopActiveRequestMonitoring() {
    _activeRequestCheckTimer?.cancel();
    _activeRequestCheckTimer = null;
  }

  Future<void> _verifyActiveRequest() async {
    if (_activeRequest == null) {
      _stopActiveRequestMonitoring();
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final requestId = _activeRequest!['id'];
      final currentRequest = await supabase
          .from('requests')
          .select('id, status, mechanic_id, rejection_reason')
          .eq('id', requestId)
          .maybeSingle();

      if (currentRequest == null) {
        // Request was deleted
        print('Active request was deleted during verification');
        _clearActiveRequest('Request was cancelled by the user');
      } else if (currentRequest['status'] != 'accepted' || 
                 currentRequest['mechanic_id'] != user.id) {
        // Request status changed or reassigned
        print('Active request status/assignment changed during verification: ${currentRequest}');
        
        final rejectionReason = currentRequest['rejection_reason'];
        
        // Don't show message if it was rejected by a mechanic
        if (rejectionReason == 'mechanic_rejected') {
          print('Request was rejected by mechanic, clearing silently');
          _locationUpdateTimer?.cancel();
          _acceptedRequestId = null;
          _lastUpdatedPosition = null;
          _stopActiveRequestMonitoring();
          
          if (mounted) {
            setState(() {
              _activeRequest = null;
              _isModalMinimized = false;
            });
          }
          return;
        }
        
        String reason = 'Request was cancelled by the user';
        if (currentRequest['status'] == 'completed') {
          reason = 'Request was completed';
        } else if (currentRequest['mechanic_id'] != user.id) {
          reason = 'Request was assigned to another mechanic';
        }
        _clearActiveRequest(reason);
      } else {
        print('Active request verified: still valid');
      }
    } catch (e) {
      print('Error verifying active request: $e');
      // Don't clear on error, might be temporary network issue
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to accept requests')),
        );
      }
      return;
    }

    // Check if mechanic already has an active emergency request
    try {
      final existingActiveRequest = await supabase
          .from('requests')
          .select('id, status')
          .eq('mechanic_id', user.id)
          .eq('status', 'accepted')
          .eq('request_type', 'emergency')
          .maybeSingle();

      if (existingActiveRequest != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active emergency request. Please complete it first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify active requests. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      }
      
      final updateResponse = await supabase
          .from('requests')
          .update(updateData)
          .eq('id', requestId)
          .select();
      
      if (updateResponse.isEmpty) {
        throw Exception('No rows were updated. This might be due to RLS policy restrictions.');
      }

      // Store active request details
      final request = _sosRequests.firstWhere((req) => req['id'] == requestId);
      if (mounted) {
        setState(() {
          _activeRequest = Map<String, dynamic>.from(request);
          _sosRequests.removeWhere((req) => req['id'] == requestId);
          _activeRequests = _sosRequests.length.toString();
          _isModalMinimized = false;
        });
      }

      // Start monitoring the active request
      _startActiveRequestMonitoring();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (_currentPosition != null) {
        _startLocationUpdateTimer(requestId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location tracking unavailable. Please ensure GPS is enabled.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('row-level security') || e.toString().contains('RLS') || e.toString().contains('policy')) {
        errorMessage = 'Permission denied: Unable to update request. RLS policy issue detected.';
      } else if (e.toString().contains('No rows were updated')) {
        errorMessage = 'Request could not be updated. This may be due to database security policies.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('permission') || e.toString().contains('auth')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else {
        errorMessage = 'Unable to accept request. Please try again.';
      }
      
      if (mounted) {
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
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      // Check authentication state
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('Mechanic ${user.id} rejecting request $requestId');
      
      // First, add this request to ignored_requests table to permanently blacklist it
      try {
        await supabase.from('ignored_requests').insert({
          'mechanic_id': user.id,
          'request_id': requestId,
          'ignored_at': DateTime.now().toIso8601String(),
        });
        print('Request $requestId added to ignored list for mechanic ${user.id}');
      } catch (ignoreError) {
        // If ignore insert fails, just log it but continue with rejection
        print('Warning: Failed to add request to ignored list: $ignoreError');
      }
      
      // Then update the request to make it available for other mechanics
      await supabase
          .from('requests')
          .update({
            'status': 'pending',
            'mechanic_id': null,
            'mech_lat': null,
            'mech_lng': null,
            'rejection_reason': 'mechanic_rejected', // Mark as mechanic rejection
          })
          .eq('id', requestId);

      if (mounted) {
        setState(() {
          _sosRequests.removeWhere((request) => request['id'] == requestId);
          _activeRequests = _sosRequests.length.toString();
          _activeRequest = null;
          _isModalMinimized = false;
          _isDirectionModalOpen = false; // Reset direction modal flag
          _locationUpdateTimer?.cancel();
          _acceptedRequestId = null;
          _lastUpdatedPosition = null;
        });
        // Note: Success message is shown by the calling component (direction_popup.dart)
        // to avoid duplicate notifications
      }
    } catch (e) {
      print('Error in _rejectRequest: $e');
      if (mounted) {
        String errorMessage = 'Error rejecting request';
        
        // Handle specific error types
        if (e.toString().contains('row-level security') || 
            e.toString().contains('RLS') || 
            e.toString().contains('policy')) {
          errorMessage = 'Permission denied. You may not have permission to modify this request.';
        } else if (e.toString().contains('network') || 
                   e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ignoring request: $e')),
      );
    }
  }

  void _showDirectionModal() {
    if (_activeRequest == null) return;
    
    // Set flag to indicate direction modal is opening
    setState(() {
      _isDirectionModalOpen = true;
    });
    
    // Safely extract values with proper null handling
    final userId = _activeRequest!['user_id']?.toString() ?? '';
    final guestId = _activeRequest!['guest_id']?.toString() ?? '';
    final effectiveUserId = userId.isNotEmpty ? userId : guestId;
    final requestId = _activeRequest!['id']?.toString() ?? '';
    final phone = _activeRequest!['phone']?.toString() ?? 'Contact via app';
    final userName = _activeRequest!['user_name']?.toString() ?? 'Unknown User';
    final imageUrl = _activeRequest!['image_url']?.toString() ?? '';
    
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
              double.tryParse(_activeRequest!['lat']?.toString() ?? '0.0') ?? 0.0,
              double.tryParse(_activeRequest!['lng']?.toString() ?? '0.0') ?? 0.0,
            ),
            phone: phone,
            name: userName,
            imageUrl: imageUrl,
            onReject: () => _rejectRequest(requestId),
            onMinimize: () {
              setState(() {
                _isModalMinimized = true;
                _isDirectionModalOpen = false; // Reset direction modal flag
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
        _isDirectionModalOpen = false; // Reset direction modal flag
      });
    });
  }

  Future<void> _fetchUnreadNotificationsCount() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('notification')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = response.length;
        });
      }
    } catch (e) {
      print('Error fetching unread notifications count: $e');
    }
  }

  Future<void> _checkForNewRequestsAndNotify(List<Map<String, dynamic>> newRequests) async {
    try {
      // Skip notification generation on initial load to avoid spam
      if (_isInitialLoad || _previousSosRequests.isEmpty) {
        print('Skipping notification generation - Initial load: $_isInitialLoad, Previous requests empty: ${_previousSosRequests.isEmpty}');
        print('Current requests count: ${newRequests.length}');
        _previousSosRequests = List.from(newRequests);
        return;
      }

      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Find truly new requests by comparing IDs
      final previousRequestIds = _previousSosRequests.map((r) => r['id']?.toString()).toSet();
      final newRequestsOnly = newRequests.where((request) {
        final requestId = request['id']?.toString();
        return requestId != null && !previousRequestIds.contains(requestId);
      }).toList();

      print('Previous request IDs: $previousRequestIds');
      print('Current request IDs: ${newRequests.map((r) => r['id']?.toString()).toSet()}');
      print('New requests found: ${newRequestsOnly.length}');

      // Generate notifications for each new request
      for (final request in newRequestsOnly) {
        final userName = request['user_name'] ?? 'Someone';
        final isGuest = request['guest_id'] != null;
        
        // Create more descriptive notification body
        String notificationBody;
        if (isGuest) {
          notificationBody = 'A guest user needs your help';
        } else {
          notificationBody = '$userName needs your help';
        }
        
        try {
          await supabase.from('notification').insert({
            'user_id': user.id,
            'notification_title': 'New Emergency Request',
            'notification_body': notificationBody,
            'is_read': false,
          });
          
          print('Notification created for new request from ${isGuest ? 'guest user' : userName}');
        } catch (e) {
          print('Error creating notification for request ${request['id']}: $e');
        }
      }

      // Update the previous requests list for next comparison
      _previousSosRequests = List.from(newRequests);
      
      // Refresh unread notifications count if we created any notifications
      if (newRequestsOnly.isNotEmpty) {
        _fetchUnreadNotificationsCount();
      }
    } catch (e) {
      print('Error in _checkForNewRequestsAndNotify: $e');
    }
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
                                  actions: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: IconButton(
                                        icon: Stack(
                                          children: [
                                            Icon(
                                              Icons.notifications_outlined,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                            // Notification badge - only show if there are unread notifications
                                            if (_unreadNotificationsCount > 0)
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  constraints: const BoxConstraints(
                                                    minWidth: 18,
                                                    minHeight: 18,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      _unreadNotificationsCount > 99 
                                                          ? '99+' 
                                                          : _unreadNotificationsCount.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        onPressed: () async {
                                          // Navigate to notifications and refresh count when returning
                                          await Navigator.pushNamed(context, '/notifications');
                                          if (mounted) {
                                            _fetchUnreadNotificationsCount();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
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
      // Floating action button for active emergency request
      floatingActionButton: (_activeRequest != null && !_isModalMinimized && !_isDirectionModalOpen) 
        ? Container(
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
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: "main_navigation_fab", // Unique hero tag
              onPressed: _showDirectionModal,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  Colors.red.shade400,
                  Colors.red.shade600,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: "bubble_navigation_fab", // Unique hero tag
              onPressed: _showDirectionModal,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.navigation_rounded,
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