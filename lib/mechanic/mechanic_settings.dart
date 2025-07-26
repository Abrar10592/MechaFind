import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MechanicSettings extends StatefulWidget {
  const MechanicSettings({super.key});

  @override
  State<MechanicSettings> createState() => _MechanicSettingsState();
}

class _MechanicSettingsState extends State<MechanicSettings> {
  bool pushNotifications = true;
  bool locationAccess = true;
  bool autoAcceptRequests = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    // DO NOT use context here for EasyLocalization
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLanguage = context.locale.languageCode;
  }

  Future<void> _changeLanguage(String langCode) async {
    final newLocale = Locale(langCode);
    await context.setLocale(newLocale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang_code', langCode);

    setState(() {
      _selectedLanguage = langCode;
    });

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(langCode == 'en' ? 'Language changed to English' : 'ভাষা বাংলায় পরিবর্তিত হয়েছে'),
        duration: Duration(seconds: 2),
      ),
    );

    // Remove the navigation reset - this was causing the jump to landing page
    // if (mounted) {
    //   Navigator.of(context).popUntil((route) => route.isFirst);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.locale.languageCode == 'en' ? 'Settings' : 'সেটিংস'), 
        centerTitle: true
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Settings' : 'সেটিংস'),
          _buildToggleItem(
            context.locale.languageCode == 'en' ? 'Push Notifications' : 'পুশ নোটিফিকেশন', 
            pushNotifications, 
            (value) {
              setState(() {
                pushNotifications = value;
              });
            }
          ),
          _buildToggleItem(
            context.locale.languageCode == 'en' ? 'Location Access' : 'অবস্থান অ্যাক্সেস', 
            locationAccess, 
            (value) {
              setState(() {
                locationAccess = value;
              });
            }
          ),
          Text(
            context.locale.languageCode == 'en' ? 'Language' : 'ভাষা',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          RadioListTile(
            title: Text('English'),
            value: 'en',
            groupValue: _selectedLanguage,
            onChanged: (value) => _changeLanguage(value as String),
          ),
          RadioListTile(
            title: Text('বাংলা (Bangla)'),
            value: 'bn',
            groupValue: _selectedLanguage,
            onChanged: (value) => _changeLanguage(value as String),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Work Preferences' : 'কাজের পছন্দ'),
          _buildToggleItem(
            context.locale.languageCode == 'en' ? 'Auto Accept Requests' : 'স্বয়ংক্রিয় অনুরোধ গ্রহণ', 
            autoAcceptRequests, 
            (value) {
              setState(() {
                autoAcceptRequests = value;
              });
            }
          ),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Service Area' : 'সেবা এলাকা', 
            context.locale.languageCode == 'en' ? 'Update work area' : 'কাজের এলাকা আপডেট করুন'
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Account' : 'অ্যাকাউন্ট'),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Profile Information' : 'প্রোফাইল তথ্য', 
            context.locale.languageCode == 'en' ? 'Update personal details' : 'ব্যক্তিগত বিবরণ আপডেট করুন'
          ),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Contact Information' : 'যোগাযোগের তথ্য', 
            context.locale.languageCode == 'en' ? 'Update contact' : 'যোগাযোগ আপডেট করুন'
          ),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Privacy & Security' : 'গোপনীয়তা ও নিরাপত্তা', 
            context.locale.languageCode == 'en' ? 'Manage privacy' : 'গোপনীয়তা পরিচালনা করুন'
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Support' : 'সহায়তা'),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Help & Support' : 'সাহায্য ও সহায়তা', 
            context.locale.languageCode == 'en' ? 'Get help' : 'সাহায্য পান'
          ),
          _buildListItem(
            context.locale.languageCode == 'en' ? 'Contact Support' : 'সহায়তা যোগাযোগ', 
            context.locale.languageCode == 'en' ? 'Reach team' : 'টিমের সাথে যোগাযোগ করুন'
          ),
          const SizedBox(height: 20),
          _buildSignOutButton(context),
          const SizedBox(height: 10),
          _buildDeleteButton(context),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
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
      leading: const Icon(Icons.circle, color: Colors.blue),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.blue),
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
            SnackBar(
              content: Text(context.locale.languageCode == 'en' ? 'Signed out' : 'সাইন আউট হয়েছে')
            )
          );
        },
        child: Text(context.locale.languageCode == 'en' ? 'Sign Out' : 'সাইন আউট'),
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
              title: Text(context.locale.languageCode == 'en' ? 'Delete Account' : 'অ্যাকাউন্ট মুছুন'),
              content: Text(context.locale.languageCode == 'en' ? 'Are you sure you want to delete your account? This action cannot be undone.' : 'আপনি কি নিশ্চিত যে আপনি আপনার অ্যাকাউন্ট মুছতে চান? এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.locale.languageCode == 'en' ? 'Cancel' : 'বাতিল'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.locale.languageCode == 'en' ? 'Delete' : 'মুছুন'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.locale.languageCode == 'en' ? 'Account deleted' : 'অ্যাকাউন্ট মুছে ফেলা হয়েছে')
              )
            );
          }
        },
        child: Text(context.locale.languageCode == 'en' ? 'Delete Account' : 'অ্যাকাউন্ট মুছুন'),
      ),
    );
  }
}
