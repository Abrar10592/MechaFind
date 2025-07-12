import 'package:flutter/material.dart';

class MechanicSettings extends StatefulWidget {
  const MechanicSettings({super.key});

  @override
  State<MechanicSettings> createState() => _MechanicSettingsState();
}

class _MechanicSettingsState extends State<MechanicSettings> {
  bool pushNotifications = true;
  bool locationAccess = true;
  bool autoAcceptRequests = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('Settings'),
          _buildToggleItem('Push notifications for new SOS requests', pushNotifications, (value) {
            setState(() {
              pushNotifications = value;
            });
          }),
          _buildToggleItem('Allow location access for better service', locationAccess, (value) {
            setState(() {
              locationAccess = value;
            });
          }),
          SizedBox(height: 20),
          _buildSectionTitle('Work Preferences'),
          _buildToggleItem('Auto-accept requests within 1km', autoAcceptRequests, (value) {
            setState(() {
              autoAcceptRequests = value;
            });
          }),
          _buildListItem('Service Area', 'Update your working area'),
          SizedBox(height: 20),
          _buildSectionTitle('Account'),
          _buildListItem('Profile Information', 'Update your personal details'),
          _buildListItem('Contact Information', 'Update phone and email'),
          _buildListItem('Privacy & Security', 'Manage your privacy settings'),
          SizedBox(height: 20),
          _buildSectionTitle('Support'),
          _buildListItem('Help & Support', 'Get help with the app'),
          _buildListItem('Contact Support', 'Get in touch with our team'),
          SizedBox(height: 20),
          _buildSignOutButton(context),
          SizedBox(height: 10),
          _buildDeleteButton(context),
          SizedBox(height: 10),

          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _buildToggleItem(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  Widget _buildListItem(String title, String subtitle) {
    return ListTile(
      leading: Icon(Icons.circle, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey)),
      trailing: Icon(Icons.chevron_right, color: Colors.blue),
      onTap: () {},
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signed out')),
          );
        },
        child: Text('Sign Out'),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete Account'),
              content: Text('Are you sure you want to delete your account? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Account deletion confirmed (not implemented)')),
            );
          }
        },
        child: Text('Delete Account'),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Version 1.0.0 © 2024 Mechanic Services',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

