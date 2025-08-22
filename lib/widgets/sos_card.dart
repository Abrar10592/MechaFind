import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:mechfind/utils.dart';

class SosCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final LatLng? current_location;
  final VoidCallback? onIgnore;
  final VoidCallback? onAccept;

  const SosCard({
    super.key,
    required this.request,
    required this.current_location,
    this.onIgnore,
    this.onAccept,
  });

  @override
  State<SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<SosCard> with TickerProviderStateMixin {
  double? distanceInKm;
  String? placeName;
  bool _isPlaceNameLoading = true;
  bool _isExpanded = false;
  
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _iconRotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    _iconRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    ));
    
    _calculateDistance();
    _fetchPlaceName();
  }
  
  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _calculateDistance() {
    try {
      if (widget.current_location != null &&
          widget.request['lat'] != null &&
          widget.request['lng'] != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          widget.current_location!.latitude,
          widget.current_location!.longitude,
          widget.request['lat'],
          widget.request['lng'],
        );
        setState(() {
          distanceInKm = distanceInMeters / 1000;
        });
      }
    } catch (e) {
      // Distance calculation failed, distanceInKm remains null
      print('Error calculating distance: $e');
    }
  }

  Future<void> _fetchPlaceName() async {
    final lat = widget.request['lat'];
    final lng = widget.request['lng'];

    if (lat == null || lng == null) {
      setState(() {
        placeName = 'Location unavailable';
        _isPlaceNameLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ&types=place,locality,address&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Network timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          setState(() {
            placeName = features.first['place_name'] ?? 'Nearby location';
            _isPlaceNameLoading = false;
          });
        } else {
          setState(() {
            placeName = 'Nearby location';
            _isPlaceNameLoading = false;
          });
        }
      } else {
        setState(() {
          placeName = 'Nearby location';
          _isPlaceNameLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        placeName = 'Nearby location';
        _isPlaceNameLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    // Get user data from nested structure
    final userData = request['users'] ?? {};
    final userName = userData['full_name'] ?? request['user_name'] ?? 'Unknown User';
    final userImageUrl = userData['image_url'] ?? request['image_url'];
    final userPhone = userData['phone'] ?? request['phone'] ?? 'N/A';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.blue.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header - Always visible
            _buildCompactHeader(userName, userImageUrl, request),
            
            // Action buttons - Always visible
            const SizedBox(height: 12),
            _buildActionButtons(),
            
            // Expand button at bottom center
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: _toggleExpanded,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedBuilder(
                    animation: _iconRotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconRotationAnimation.value * 3.14159,
                        child: Icon(
                          Icons.expand_more,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Expandable content
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildExpandedContent(request, userPhone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader(String userName, dynamic userImageUrl, Map<String, dynamic> request) {
    return Row(
      children: [
        // User avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 20,
              backgroundImage: (userImageUrl != null && 
                  userImageUrl.toString().isNotEmpty)
                  ? NetworkImage(userImageUrl.toString())
                  : const AssetImage('zob_assets/user_icon.png')
                      as ImageProvider,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and urgent badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userName.toString(),
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body + 1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: FontSizes.caption - 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Vehicle and distance
              Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request['vehicle']?.toString() ?? 'Unknown Vehicle',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: FontSizes.caption,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (distanceInKm != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${distanceInKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: FontSizes.caption - 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _isPlaceNameLoading
                        ? Text(
                            'Loading location...',
                            style: AppTextStyles.body.copyWith(
                              fontSize: FontSizes.caption,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Text(
                            placeName ?? 'Nearby location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              fontSize: FontSizes.caption,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: OutlinedButton.icon(
              onPressed: widget.onIgnore,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(
                'ignore'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  Colors.blue,
                  Colors.blue.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: widget.onAccept,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                'accept'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> request, String userPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Issue Image
        if (request['image'] != null && request['image'].toString().isNotEmpty)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                request['image'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey.shade100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image not available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: FontSizes.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Description section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'issue_description'.tr(),
                    style: AppTextStyles.heading.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: FontSizes.body,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request['description']?.toString() ?? 'No description provided',
                style: AppTextStyles.body.copyWith(
                  fontSize: FontSizes.body,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Phone info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_rounded,
                size: 20,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Number',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: FontSizes.caption,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userPhone.toString(),
                    style: AppTextStyles.body.copyWith(
                      fontSize: FontSizes.body,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
