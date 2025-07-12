import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/data/demo_data.dart';
import 'package:mechfind/widgets/direction_popup.dart';
import 'package:mechfind/widgets/sos_card.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MechanicLandingScreen extends StatefulWidget {
  const MechanicLandingScreen({super.key});

  @override
  State<MechanicLandingScreen> createState() => _MechanicLandingScreenState();
}

class _MechanicLandingScreenState extends State<MechanicLandingScreen>
    with WidgetsBindingObserver {
  final Location _locationController = Location();
  LatLng? _currentPosition;
  late GoogleMapController _mapController;
  bool _hasListenerAttached = false;
  bool _hasRequestedPermission = false;
  // Add this:
  late List<Map<String, dynamic>> _sosRequests;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationSetup();
    _sosRequests = List<Map<String, dynamic>>.from(demoData);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!serviceEnabled && !_hasRequestedPermission) {
      serviceEnabled = await _locationController.requestService();
      _hasRequestedPermission = true;
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _locationController
        .hasPermission();
    if (permissionGranted == PermissionStatus.denied &&
        !_hasRequestedPermission) {
      _hasRequestedPermission = true;
      permissionGranted = await _locationController.requestPermission();
    }

    if (permissionGranted == PermissionStatus.granted) {
      if (!_hasListenerAttached) {
        _locationController.onLocationChanged.listen((
          LocationData locationData,
        ) {
          if (locationData.latitude != null && locationData.longitude != null) {
            final newPosition = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
            if (mounted) {
              setState(() {
                _currentPosition = newPosition;
              });
            }
          }
        });
        _hasListenerAttached = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2.0,
        title: Text(
          'Mechanic Dashboard',
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
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard("12", "Completed Today")),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard("2", "Active Request")),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard("4.8", "Rating")),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Active SOS Signals",
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.subHeading,
                fontFamily: AppFonts.primaryFont,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _sosRequests.length,
                itemBuilder: (context, index) {
                  final request = _sosRequests[index];
                  return Sos_Card(
                    request: request,
                    current_location: _currentPosition,
                    onIgnore: () {
                      setState(() {
                        _sosRequests.removeAt(index);
                      });
                    },
                    onAccept: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DirectionPopup(
                          mechanicLocation: _currentPosition,
                          requestLocation: LatLng(
                            request['lat'],
                            request['lng'],
                          ),
                          phone: request['phone'],
                        ),
                      );
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
