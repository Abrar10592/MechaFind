import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/profile/mechanic_profile_page.dart';
import 'screens/chat/chat_screen.dart';
import 'services/mechanic_service.dart';
import 'services/find_mechanic_service.dart';
import 'utils/page_transitions.dart';
import 'utils.dart';

class DetailedMechanicCard extends StatefulWidget {
  final Map<String, dynamic> mechanic;

  const DetailedMechanicCard({super.key, required this.mechanic});

  @override
  State<DetailedMechanicCard> createState() => _DetailedMechanicCardState();
}

class _DetailedMechanicCardState extends State<DetailedMechanicCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mechanic = widget.mechanic;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white,
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Header with Avatar, Name + Status Dot
                _buildEnhancedHeader(mechanic),
                const SizedBox(height: 12),

                // Enhanced Address
                if (mechanic['address'] != null && mechanic['address'].toString().isNotEmpty)
                  _buildAddressSection(mechanic),

                // Enhanced Distance, Rating, Response Time
                _buildStatsRow(mechanic),

                const SizedBox(height: 16),

                // Enhanced Services
                if (mechanic['services'] != null && (mechanic['services'] as List).isNotEmpty)
                  _buildServicesSection(mechanic),

                // Enhanced Action Buttons
                _buildActionButtons(context, mechanic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Make phone call to mechanic
  void _makePhoneCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw Exception('Could not launch phone dialer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Open chat with mechanic
  void _openChat(BuildContext context, Map<String, dynamic> mechanic) {
    final mechanicId = mechanic['id'];
    if (mechanicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start chat: Mechanic ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to chat screen with modal transition
    NavigationHelper.modalToPage(
      context,
      ChatScreen(
        mechanicId: mechanicId.toString(),
        mechanicName: mechanic['name'] ?? 'Mechanic',
        mechanicImageUrl: mechanic['image_url'],
      ),
    );
  }

  /// Open mechanic profile
  void _openProfile(BuildContext context, Map<String, dynamic> mechanic) async {
    final mechanicId = mechanic['id'];
    if (mechanicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open profile: Mechanic ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch complete mechanic details
      final mechanicDetails = await FindMechanicService.getMechanicById(mechanicId.toString());
      
      // Close loading indicator
      Navigator.of(context).pop();

      if (mechanicDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load mechanic profile'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convert to Mechanic model for profile page
      final mechanicModel = MechanicService.convertToMechanic(mechanicDetails);
      
      // Navigate to profile with hero transition
      NavigationHelper.heroToPage(
        context,
        MechanicProfilePage(mechanic: mechanicModel),
      );
    } catch (e) {
      // Close loading indicator if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEnhancedHeader(Map<String, dynamic> mechanic) {
    final isOnline = mechanic['online'] ?? false;
    
    return Row(
      children: [
        // Enhanced Profile Image with gradient border
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isOnline 
                  ? [AppColors.greenPrimary, AppColors.greenSecondary]
                  : [Colors.grey[400]!, Colors.grey[600]!],
            ),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[100],
            backgroundImage: mechanic['image_url'] != null && mechanic['image_url'].toString().isNotEmpty
                ? NetworkImage(mechanic['image_url'])
                : null,
            child: mechanic['image_url'] == null || mechanic['image_url'].toString().isEmpty
                ? Icon(
                    Icons.person,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 24,
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
                mechanic['name'] ?? 'Unknown Mechanic',
                style: TextStyle(
                  fontSize: FontSizes.subHeading,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: AppFonts.primaryFont,
                ),
              ),
              if (mechanic['phone'] != null && mechanic['phone'].toString().isNotEmpty)
                Text(
                  mechanic['phone'],
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: FontSizes.caption,
                    fontFamily: AppFonts.secondaryFont,
                  ),
                ),
            ],
          ),
        ),
        // Enhanced status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? AppColors.greenPrimary : Colors.grey[400],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: FontSizes.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> mechanic) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mechanic['address'],
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: FontSizes.body,
                fontFamily: AppFonts.secondaryFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> mechanic) {
    return Row(
      children: [
        // Distance badge
        if (mechanic['distance'] != null && mechanic['distance'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tealPrimary.withOpacity(0.1),
                  AppColors.tealSecondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.tealPrimary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me, size: 14, color: AppColors.tealPrimary),
                const SizedBox(width: 4),
                Text(
                  mechanic['distance'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.tealPrimary,
                    fontSize: FontSizes.caption,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),
        
        // Rating section
        if (mechanic['rating'] != null && mechanic['rating'] > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${mechanic['rating'].toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
                if (mechanic['reviews'] != null && mechanic['reviews'] > 0)
                  Text(
                    ' (${mechanic['reviews']})',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: FontSizes.caption,
                    ),
                  ),
              ],
            ),
          ),
        
        const Spacer(),
        
        // Response time
        if (mechanic['response'] != null && mechanic['response'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.greenPrimary.withOpacity(0.1),
                  AppColors.greenSecondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.greenPrimary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 14, color: AppColors.greenPrimary),
                const SizedBox(width: 4),
                Text(
                  mechanic['response'],
                  style: TextStyle(
                    color: AppColors.greenPrimary,
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildServicesSection(Map<String, dynamic> mechanic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: TextStyle(
              fontSize: FontSizes.body,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: AppFonts.primaryFont,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List<Widget>.from(
              (mechanic['services'] as List).map(
                (service) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    service.toString(),
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> mechanic) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.greenPrimary, AppColors.greenSecondary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.greenPrimary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _makePhoneCall(context, mechanic['phone']),
              icon: const Icon(Icons.call, size: 18),
              label: const Text(
                'Call',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: OutlinedButton.icon(
              onPressed: () => _openChat(context, mechanic),
              icon: const Icon(Icons.message, size: 18),
              label: const Text(
                'Chat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _openProfile(context, mechanic),
              icon: const Icon(Icons.person, size: 18),
              label: const Text(
                'Profile',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
}
