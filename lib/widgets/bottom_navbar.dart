import 'package:flutter/material.dart';

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
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find Mechanics'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: onTap ?? (index) {
        switch (index) {
          case 0:
            Navigator.pushNamedAndRemoveUntil(context, '/userHome', (route) => false);
            break;
          case 1:
            Navigator.pushNamed(context, '/find-mechanics');
            break;
          case 2:
            // Messages - can be implemented later
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Messages feature coming soon'),
            ));
            break;
          case 3:
            Navigator.pushNamed(context, '/history');
            break;
          case 4:
            Navigator.pushNamed(context, '/settings');
            break;
        }
      },
    );
  }
}
