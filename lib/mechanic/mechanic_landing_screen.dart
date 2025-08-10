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
    with WidgetsBindingObserver {
  final Location _locationController = Location();
  final SupabaseClient supabase = Supabase.instance.client;
  LatLng? _currentPosition;
  bool _hasListenerAttached = false;
  List<Map<String, dynamic>> _sosRequests = [];
  bool _isLoading = true;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationSetup();
    // Don't call _fetchMechanicData() here - it will be called after location is ready
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.unsubscribe();
    _debounceTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _locationController.onLocationChanged.drain();
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
      await supabase
          .from('requests')
          .update({
            'mech_lat': position.latitude.toString(),
            'mech_lng': position.longitude.toString(),
          })
          .eq('id', requestId);
      print('Mechanic location updated for request $requestId: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating mechanic location for request $requestId: $e');
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
      _isLoading = true;
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

      final pendingResponse = await supabase
          .from('requests')
          .select('id, user_id, vehicle, description, image, lat, lng, users!left(full_name, phone, image_url)')
          .eq('status', 'pending')
          .filter('mechanic_id', 'is', null);

      print('Pending response raw: $pendingResponse');

      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', user.id);

      print('Reviews fetched: ${reviewsResponse.length}');

      List<Map<String, dynamic>> filteredRequests = [];
      const double maxDistanceKm = 10.0;
      final latlng.Distance distanceCalc = const latlng.Distance();
      
      // Convert _currentPosition to latlng.LatLng for distance calculation
      latlng.LatLng? currentLatLng;
      if (_currentPosition != null) {
        currentLatLng = latlng.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        print('🔄 Current position converted: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
      } else {
        print('❌ _currentPosition is null');
      }
      
      for (var request in pendingResponse) {
        print('Request data: $request');
        final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
        
        print('🎯 Parsed coordinates: lat=$lat, lng=$lng');
        print('🎯 Validation check: currentLatLng != null = ${currentLatLng != null}, lat != 0.0 = ${lat != 0.0}, lng != 0.0 = ${lng != 0.0}');
        
        // Calculate distance between mechanic and SOS request using the same logic as mechanic_map
        if (currentLatLng != null && lat != 0.0 && lng != 0.0) {
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
            filteredRequests.add({
              'id': request['id'],
              'user_id': request['user_id'],
              'vehicle': request['vehicle']?.toString() ?? 'Unknown',
              'description': request['description']?.toString() ?? 'No description',
              'image': request['image']?.toString(),
              'lat': lat,
              'lng': lng,
              'user_name': request['users']?['full_name']?.toString() ?? 'Unknown',
              'phone': request['users']?['phone']?.toString() ?? 'N/A',
              'image_url': request['users']?['image_url']?.toString(),
            });
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
      print('   Filtered requests (within ${maxDistanceKm}km): ${filteredRequests.length}');
      print('Filtered requests: $filteredRequests');

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
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
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

    try {
      final updateData = {
        'mechanic_id': user.id,
        'status': 'accepted',
      };
      if (_currentPosition != null) {
        updateData['mech_lat'] = _currentPosition!.latitude.toString();
        updateData['mech_lng'] = _currentPosition!.longitude.toString();
      } else {
        print('Warning: No current position available when accepting request $requestId');
      }

      await supabase
          .from('requests')
          .update(updateData)
          .eq('id', requestId);

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
      String errorMessage;
      if (e.toString().contains('network') || e.toString().contains('connection')) {
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
        const SnackBar(content: Text('Request ignored')),
      );
      print('Request $requestId ignored');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e')),
      );
      print('Error rejecting request $requestId: $e');
    }
  }

  void _showDirectionModal() {
    if (_activeRequest == null) return;
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
            user_id: _activeRequest!['user_id'],
            requestId: _activeRequest!['id'],
            requestLocation: latlng.LatLng(
              _activeRequest!['lat'],
              _activeRequest!['lng'],
            ),
            phone: _activeRequest!['phone'],
            name: _activeRequest!['user_name'],
            imageUrl: _activeRequest!['image_url'],
            onReject: () => _rejectRequest(_activeRequest!['id']),
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
      appBar: AppBar(
        elevation: 2.0,
        title: Text(
          isEnglish ? "Mechanic Dashboard" : "মেকানিক ড্যাশবোর্ড",
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontSize: FontSizes.heading,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: AppTextStyles.body))
                  : Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: _buildStatCard(
                                      _completedToday, isEnglish ? "Completed Today" : "আজ সম্পন্ন")),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _buildStatCard(
                                      _activeRequests, isEnglish ? "Active Request" : "সক্রিয় অনুরোধ")),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _buildStatCard(
                                      _rating, isEnglish ? "Rating" : "রেটিং")),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isEnglish ? "Active SOS Signals" : "সক্রিয় এসওএস সংকেত",
                            style: AppTextStyles.heading.copyWith(
                              fontSize: FontSizes.subHeading,
                              fontFamily: AppFonts.primaryFont,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _sosRequests.isEmpty
                                ? Center(
                                    child: Text(
                                      isEnglish ? "No active requests" : "কোন সক্রিয় অনুরোধ নেই",
                                      style: AppTextStyles.body,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _sosRequests.length,
                                    itemBuilder: (context, index) {
                                      final request = _sosRequests[index];
                                      print('Rendering SOS card: $request, current_location: $_currentPosition');
                                      return SosCard(
                                        request: request,
                                        current_location: _currentPosition,
                                        onIgnore: () => _rejectRequest(request['id']),
                                        onAccept: () {
                                          _acceptRequest(request['id']).then((_) {
                                            _showDirectionModal();
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
          if (_isModalMinimized && _activeRequest != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showDirectionModal,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.map, color: Colors.white),
                tooltip: isEnglish ? 'Open Request' : 'অনুরোধ খুলুন',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(7.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 28,
                  color: AppColors.primary,
                  fontFamily: AppFonts.primaryFont,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  fontSize: FontSizes.body,
                  fontFamily: AppFonts.secondaryFont,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}