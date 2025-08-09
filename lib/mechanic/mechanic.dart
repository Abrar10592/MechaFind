import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mechfind/mechanic/message_screen.dart';
import 'package:mechfind/utils.dart';
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

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const MechanicLandingScreen();
      case 1:
        return const MechanicMap();
      case 2:
        return const MessagesScreen();
      
      case 3:
        return const MechanicProfile();
      case 4:
        return const MechanicSettings();
      default:
        return const MechanicLandingScreen();
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
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontFamily: AppFonts.primaryFont,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: AppFonts.secondaryFont,
          fontWeight: FontWeight.w400,
        ),
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: 'map'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_rounded),
            label: 'Chat'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'profile'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'settings'.tr(),
          ),
        ],
      ),
    );
  }
}
