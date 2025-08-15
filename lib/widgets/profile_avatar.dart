import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/user_service.dart';
import '../services/profile_update_notifier.dart';
import '../utils.dart';

class ProfileAvatar extends StatelessWidget {
  final double radius;
  final String? profilePicUrl;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const ProfileAvatar({
    Key? key,
    this.radius = 20,
    this.profilePicUrl,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: showBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor ?? AppColors.primary,
                  width: 2,
                ),
              )
            : null,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          child: profilePicUrl != null && profilePicUrl!.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profilePicUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    // Add cache key to force refresh when image is updated
                    cacheKey: '${profilePicUrl}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}', // Refresh every minute
                    placeholder: (context, url) => Container(
                      width: radius * 2,
                      height: radius * 2,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: radius * 0.8,
                        color: Colors.grey[600],
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print('Error loading profile image: $error');
                      print('Failed URL: $url');
                      return Icon(
                        Icons.person,
                        size: radius * 0.8,
                        color: Colors.grey[600],
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.person,
                  size: radius * 0.8,
                  color: Colors.grey[600],
                ),
        ),
      ),
    );
  }
}

class CurrentUserAvatar extends StatefulWidget {
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const CurrentUserAvatar({
    Key? key,
    this.radius = 20,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  State<CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<CurrentUserAvatar> {
  String? _profilePicUrl;
  bool _isLoading = true;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
    
    // Listen for profile updates
    ProfileUpdateNotifier().addListener(_onProfileUpdated);
  }

  @override
  void dispose() {
    ProfileUpdateNotifier().removeListener(_onProfileUpdated);
    super.dispose();
  }

  void _onProfileUpdated() {
    // Refresh profile picture when notified of updates
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      final profilePicUrl = await UserService.getCurrentUserProfilePicture();
      print('ProfileAvatar: Loaded profile pic URL: $profilePicUrl');
      if (mounted) {
        setState(() {
          _profilePicUrl = profilePicUrl;
          // Create a unique cache key with timestamp to force refresh
          _cacheKey = profilePicUrl != null 
              ? '${profilePicUrl}_${DateTime.now().millisecondsSinceEpoch}'
              : null;
          _isLoading = false;
        });
        
        // Also clear any existing cache for this URL
        if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
          try {
            await CachedNetworkImage.evictFromCache(profilePicUrl);
            print('ProfileAvatar: Cleared cache for updated image');
          } catch (e) {
            print('ProfileAvatar: Could not clear cache: $e');
          }
        }
      }
    } catch (e) {
      print('ProfileAvatar: Error loading profile picture: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add a method to refresh the profile picture
  void refresh() {
    setState(() {
      _isLoading = true;
    });
    _loadProfilePicture();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey[300],
        child: SizedBox(
          width: widget.radius * 0.8,
          height: widget.radius * 0.8,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      decoration: widget.showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.borderColor ?? AppColors.primary,
                width: 2,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey[300],
        child: _profilePicUrl != null && _profilePicUrl!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _profilePicUrl!,
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  fit: BoxFit.cover,
                  // Use unique cache key to force refresh
                  cacheKey: _cacheKey,
                  placeholder: (context, url) => Container(
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: widget.radius * 0.8,
                      color: Colors.grey[600],
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    print('CurrentUserAvatar: Error loading image: $error');
                    print('CurrentUserAvatar: Failed URL: $url');
                    return Icon(
                      Icons.person,
                      size: widget.radius * 0.8,
                      color: Colors.grey[600],
                    );
                  },
                ),
              )
            : Icon(
                Icons.person,
                size: widget.radius * 0.8,
                color: Colors.grey[600],
              ),
      ),
    );
  }
}
