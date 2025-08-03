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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationSetup();
    _fetchMechanicData();
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
          _errorMessage = 'Location service is disabled';
          _isLoading = false;
        });
        print('Location service still disabled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
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
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        print('Location permission status: $permissionGranted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please grant location permissions')),
        );
        return;
      }
    }
    print('Location permission granted');

    try {
      final locationData = await _locationController.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location fetch timed out');
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
          });
          print('One-time location fetched: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        }
      } else {
        print('Invalid one-time location data: $locationData');
      }
    } catch (e) {
      print('Error fetching one-time location: $e');
      setState(() {
        _errorMessage = 'Failed to fetch location: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    }
  }

  void _startLocationUpdateTimer(String requestId) {
    _locationUpdateTimer?.cancel(); // Cancel any existing timer
    _acceptedRequestId = requestId;
    _lastUpdatedPosition = _currentPosition;
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_acceptedRequestId == null || !mounted) {
        timer.cancel();
        print('Location update timer canceled: No active request or widget disposed');
        return;
      }
      // Check if the request is still active
      final request = await supabase
          .from('requests')
          .select('status')
          .eq('id', _acceptedRequestId ?? '')
          .single();
      if (request['status'] != 'accepted') {
        timer.cancel();
        _acceptedRequestId = null;
        _lastUpdatedPosition = null;
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
      for (var request in pendingResponse) {
        print('Request data: $request');
        final lat = double.tryParse(request['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(request['lng']?.toString() ?? '') ?? 0.0;
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
      }

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
              print('Stopped location updates for request ${payload.newRecord['id']} due to status: ${payload.newRecord['status']}');
            }
          },
        )
        .subscribe((status, [error]) {
          print('Subscription status: $status, Error: $error');
          if (status == 'SUBSCRIPTION_ERROR' && error != null) {
            setState(() {
              _errorMessage = 'Subscription error: $error';
            });
          }
        });
  }

  Future<void> _acceptRequest(String requestId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
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

      setState(() {
        _sosRequests.removeWhere((request) => request['id'] == requestId);
        _activeRequests = _sosRequests.length.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted')),
      );
      print('Request $requestId accepted');

      if (_currentPosition != null) {
        _startLocationUpdateTimer(requestId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to track location: Please ensure location services are enabled')),
        );
        print('Cannot start location update timer: No current position');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: $e')),
      );
      print('Error accepting request $requestId: $e');
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await supabase
          .from('requests')
          .update({'status': 'pending'})
          .eq('id', requestId);

      setState(() {
        _sosRequests.removeWhere((request) => request['id'] == requestId);
        _activeRequests = _sosRequests.length.toString();
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
      body: _isLoading
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
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        isDismissible: false,
                                        enableDrag: true,
                                        builder: (_) => DraggableScrollableSheet(
                                          initialChildSize: 0.95,
                                          minChildSize: 0.3,
                                          maxChildSize: 0.95,
                                          builder: (context, scrollController) {
                                            return DirectionPopup(
                                              requestLocation: latlng.LatLng(
                                                request['lat'],
                                                request['lng'],
                                              ),
                                              phone: request['phone'],
                                              name: request['user_name'],
                                              onReject: () => _rejectRequest(request['id']),
                                            );
                                          },
                                        ),
                                      );
                                      _acceptRequest(request['id']);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
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