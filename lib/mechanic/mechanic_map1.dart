import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mechfind/const.dart';

class MechanicMap extends StatefulWidget {
  const MechanicMap({super.key});

  @override
  State<MechanicMap> createState() => _MechanicMapState();
}

class _MechanicMapState extends State<MechanicMap> with WidgetsBindingObserver {
  final Location _locationController = Location();
  static const LatLng _defaultLocation = LatLng(23.8041, 90.4152);
  static const LatLng _defaultLocation2 = LatLng(23.7339, 90.3929);
  LatLng? _currentPosition;
  late GoogleMapController _mapController;
  bool _isMapControllerInitialized = false;
  bool _hasListenerAttached = false;
  bool _hasRequestedPermission = false;

  Map<PolylineId,Polyline> polylines={};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationSetup().then((_)=>{
      getPolylinePoints().then((coordinates) =>{
        print(coordinates),
      })

    });

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

    PermissionStatus permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied && !_hasRequestedPermission) {
      _hasRequestedPermission = true;
      permissionGranted = await _locationController.requestPermission();
    }

    if (permissionGranted == PermissionStatus.granted) {
      if (!_hasListenerAttached) {
        _locationController.onLocationChanged.listen((LocationData locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            final newPosition = LatLng(locationData.latitude!, locationData.longitude!);
            if (mounted) {
              setState(() {
                _currentPosition = newPosition;
              });
              if (_isMapControllerInitialized) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLng(newPosition),
                );
              }

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
        title: const Text(
          'Mechanic Map',
          style: TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.subHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: AppColors.background,
      body: _currentPosition == null
          ? Center(
              child: Text(
                "Loading...",
                style: AppTextStyles.body.copyWith(
                  fontFamily: AppFonts.secondaryFont,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _defaultLocation,
                zoom: 13,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _isMapControllerInitialized = true;
              },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId("current_location"),
                  position: _currentPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: "Your Location"),
                ),
                 Marker(
                  markerId: MarkerId("default_location"),
                  position: _defaultLocation,
                  infoWindow: InfoWindow(title: "Default Location"),
                ),
                 Marker(
                  markerId: MarkerId("default_location2"),
                  position: _defaultLocation2,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(title: "Default Location 2"),
                ),
                
              },
              polylines: Set<Polyline>.of(polylines.values),
            ),
    );
  }

  Future<List<LatLng>> getPolylinePoints() async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinesPoints = PolylinePoints();
    PolylineResult result = await polylinesPoints.getRouteBetweenCoordinates(
      googleApiKey: GOOGLE_MAPS_API_KEY,
      request: PolylineRequest(
        origin: PointLatLng(_defaultLocation.latitude, _defaultLocation.longitude),
         destination: PointLatLng(_defaultLocation2.latitude, _defaultLocation2.longitude),
          mode: TravelMode.driving,
          

        )
      );
      if(result.points.isNotEmpty){
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));


        }

      }else{
        print(result.errorMessage);
      }
      return polylineCoordinates;
  }
  void generatePolylines(List<LatLng> polylineCoordinates) async {
    PolylineId id=PolylineId("poly");
    Polyline polyline=Polyline(polylineId: id,color:Colors.black,points: polylineCoordinates,width: 8 );
    setState(() {
      polylines[id]=polyline;
    });
  }


}
