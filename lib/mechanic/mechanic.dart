import 'package:flutter/material.dart';
import 'package:mechfind/mechanic/mechanic_landing_screen.dart';
import 'package:mechfind/mechanic/mechanic_map.dart';
import 'package:mechfind/mechanic/mechanic_profile.dart';
import 'package:mechfind/mechanic/mechanic_settings.dart';

class Mechanic extends StatefulWidget {
  const Mechanic({super.key});

  @override
  State<Mechanic> createState() => _MechanicState();
}

class _MechanicState extends State<Mechanic> {
  int _selectedIndex = 0;

  // This method returns only the selected page
  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return MechanicLandingScreen();
      case 1:
        return MechanicMap();
      case 2:
        return MechanicProfile();
      case 3:
        return MechanicSettings();
      default:
        return MechanicLandingScreen();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex), // only selected page is rendered
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
