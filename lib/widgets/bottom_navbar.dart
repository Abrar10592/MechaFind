import 'package:flutter/material.dart';
import '../utils/page_transitions.dart';

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
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
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
        // Messages - can be implemented later with modal transition
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Messages feature coming soon'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
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
