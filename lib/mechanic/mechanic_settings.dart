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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr()), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('settings'.tr()),
          _buildToggleItem('push_notifications'.tr(), pushNotifications, (
            value,
          ) {
            setState(() {
              pushNotifications = value;
            });
          }),
          _buildToggleItem('location_access'.tr(), locationAccess, (value) {
            setState(() {
              locationAccess = value;
            });
          }),
          Text(
            'language'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          RadioListTile(
            title: Text('english'.tr()),
            value: 'en',
            groupValue: _selectedLanguage,
            onChanged: (value) => _changeLanguage(value as String),
          ),
          RadioListTile(
            title: Text('bangla'.tr()),
            value: 'bn',
            groupValue: _selectedLanguage,
            onChanged: (value) => _changeLanguage(value as String),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('work_preferences'.tr()),
          _buildToggleItem('auto_accept'.tr(), autoAcceptRequests, (value) {
            setState(() {
              autoAcceptRequests = value;
            });
          }),
          _buildListItem('service_area'.tr(), 'update_work_area'.tr()),
          const SizedBox(height: 20),
          _buildSectionTitle('account'.tr()),
          _buildListItem('profile_info'.tr(), 'update_personal_details'.tr()),
          _buildListItem('contact_info'.tr(), 'update_contact'.tr()),
          _buildListItem('privacy_security'.tr(), 'manage_privacy'.tr()),
          const SizedBox(height: 20),
          _buildSectionTitle('support'.tr()),
          _buildListItem('help_support'.tr(), 'get_help'.tr()),
          _buildListItem('contact_support'.tr(), 'reach_team'.tr()),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('signed_out'.tr())));
        },
        child: Text('sign_out'.tr()),
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
              title: Text('delete_account'.tr()),
              content: Text('delete_warning'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('cancel'.tr()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('delete'.tr()),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('account_deleted'.tr())));
          }
        },
        child: Text('delete_account'.tr()),
      ),
    );
  }
}
