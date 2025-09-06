import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mechfind/mechanic/message_screen.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/mechanic/mechanic_landing_screen.dart';
import 'package:mechfind/mechanic/mechanic_map.dart';
import 'package:mechfind/mechanic/mechanic_profile.dart';
import 'package:mechfind/mechanic/mechanic_settings.dart';
import 'package:mechfind/services/message_notification_service.dart';


class Mechanic extends StatefulWidget {
  const Mechanic({super.key});

  @override
  State<Mechanic> createState() => _MechanicState();
}

class _MechanicState extends State<Mechanic> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the message notification service
    MessageNotificationService().initialize();
  }

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
        return MechanicSettings(
          onBackToProfile: () {
            setState(() {
              _selectedIndex = 3; // Switch to profile tab
            });
          },
        );
      default:
        return const MechanicLandingScreen();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // If user taps on messages tab, mark messages as read after a short delay
    if (index == 2) {
      Future.delayed(const Duration(milliseconds: 500), () {
        MessageNotificationService().refresh();
      });
    }
  }

  Widget _buildChatTabWithBadge() {
    return ListenableBuilder(
      listenable: MessageNotificationService(),
      builder: (context, child) {
        final hasUnread = MessageNotificationService().hasUnreadMessages;
        final unreadCount = MessageNotificationService().unreadCount;
        
        return Stack(
          children: [
            const Icon(Icons.chat_rounded),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
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
            icon: _buildChatTabWithBadge(),
            label: 'messages'.tr(),
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
