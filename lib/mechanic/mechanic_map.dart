import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:mechfind/utils.dart';
//import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mechfind/const.dart';
import 'package:latlong2/latlong.dart' as latlng;


class MechanicMap extends StatefulWidget {
  const MechanicMap({super.key});

  @override
  State<MechanicMap> createState() => _MechanicMapState();
}

class _MechanicMapState extends State<MechanicMap>  {

  final MapController _mapController=MapController();
  gmaps.LatLng? _currentLocation;

  Future<void> _getUserLocation()async{

  }
  
 



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Map',
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:latlng.LatLng(23.8041, 90.4152),
              initialZoom: 14,
              minZoom: 0,
              maxZoom: 100

            ),
            children:[
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.example.mechfind'
              ),
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: DefaultLocationMarker(
                    child:Icon(Icons.location_pin,color: Colors.white,)
                  ),
                  markerSize:Size(35, 35),
                  markerDirection: MarkerDirection.heading
                   
                ),
              )

              

            ]
            )
        ],
      ),

      floatingActionButton: FloatingActionButton(onPressed: (){

      },
      backgroundColor: Colors.blue,
      child: Icon(Icons.my_location,color: Colors.white,size: 35,),
      ),
      
    );
  }

  


}
