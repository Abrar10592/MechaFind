import 'package:flutter/material.dart';
import '../services/message_notification_service.dart';
import 'profile_avatar.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60, // Reduced from 70 to prevent overflow
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                isActive: currentIndex == 0,
              ),
              _buildNavItem(
                context,
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: 'Find',
                index: 1,
                isActive: currentIndex == 1,
              ),
              _buildNavItem(
                context,
                icon: Icons.message_outlined,
                activeIcon: Icons.message,
                label: 'Messages',
                index: 2,
                isActive: currentIndex == 2,
                showBadge: true, // Enable badge for messages
              ),
              _buildNavItem(
                context,
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'History',
                index: 3,
                isActive: currentIndex == 3,
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
                isActive: currentIndex == 4,
                useProfileAvatar: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
    bool showBadge = false,
    bool useProfileAvatar = false,
  }) {
    final color = isActive ? Theme.of(context).primaryColor : Colors.grey[600];
    
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!(index);
        } else {
          _defaultNavigation(context, index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2), // Reduced padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (useProfileAvatar)
                  CurrentUserAvatar(
                    radius: 10, // Reduced size
                    showBorder: isActive,
                    borderColor: color,
                  )
                else
                  Icon(
                    isActive ? activeIcon : icon,
                    color: color,
                    size: 20, // Reduced from 24
                  ),
                if (showBadge)
                  ListenableBuilder(
                    listenable: MessageNotificationService(),
                    builder: (context, child) {
                      final hasUnread = MessageNotificationService().hasUnreadMessages;
                      if (!hasUnread) return const SizedBox.shrink();
                      
                      return Positioned(
                        right: -6, // Adjusted position
                        top: -6,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 12, // Reduced size
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 4, // Reduced size
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10, // Reduced font size
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _defaultNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Navigate to home with fade transition
        Navigator.pushNamedAndRemoveUntil(context, '/userHome', (route) => false);
        break;
      case 1:
        // Navigate to find mechanics with slide transition
        Navigator.pushNamed(context, '/find-mechanics');
        break;
      case 2:
        // Navigate to messages with slide transition
        Navigator.pushNamed(context, '/messages');
        break;
      case 3:
        // Navigate to history with slide transition
        Navigator.pushNamed(context, '/history');
        break;
      case 4:
        // Navigate to settings with slide transition
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }
}
