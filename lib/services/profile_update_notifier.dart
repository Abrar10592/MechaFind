import 'package:flutter/material.dart';

// Global notifier for profile picture updates
class ProfileUpdateNotifier extends ChangeNotifier {
  static final ProfileUpdateNotifier _instance = ProfileUpdateNotifier._internal();
  factory ProfileUpdateNotifier() => _instance;
  ProfileUpdateNotifier._internal();

  void notifyProfileUpdated() {
    print('📢 ProfileUpdateNotifier: Broadcasting profile update');
    notifyListeners();
  }
}
