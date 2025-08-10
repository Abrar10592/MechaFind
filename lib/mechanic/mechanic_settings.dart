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
  String selectedLanguage = 'en';
  
  // Privacy & Security settings
  bool otpForUnknownLogin = true;
  bool twoFactorAuth = false;
  
  // Service area
  String selectedServiceArea = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = context.locale.languageCode;
      otpForUnknownLogin = prefs.getBool('otp_unknown_login') ?? true;
      twoFactorAuth = prefs.getBool('two_factor_auth') ?? false;
      selectedServiceArea = prefs.getString('service_area') ?? 'ঢাকা, বাংলাদেশ';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('otp_unknown_login', otpForUnknownLogin);
    await prefs.setBool('two_factor_auth', twoFactorAuth);
    await prefs.setString('service_area', selectedServiceArea);
  }

  void _showContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.languageCode == 'en' ? 'Contact Support' : 'সহায়তা যোগাযোগ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.locale.languageCode == 'en' ? 'Official Email:' : 'অফিসিয়াল ইমেইল:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('support@mechfind.com.bd'),
            SizedBox(height: 10),
            Text(
              context.locale.languageCode == 'en' ? 'Office Address:' : 'অফিস ঠিকানা:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(context.locale.languageCode == 'en' 
              ? 'House 45, Road 12\nDhanmondi, Dhaka-1209\nBangladesh'
              : 'বাড়ি ৪৫, রোড ১২\nধানমন্ডি, ঢাকা-১২০৯\nবাংলাদেশ'),
            SizedBox(height: 10),
            Text(
              context.locale.languageCode == 'en' ? 'Phone:' : 'ফোন:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('+880-2-9661234'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.locale.languageCode == 'en' ? 'Close' : 'বন্ধ'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    final faqs = [
      {
        'question_en': 'How do I receive service requests?',
        'question_bn': 'আমি কিভাবে সেবার অনুরোধ পাব?',
        'answer_en': 'Keep your location on and stay online. Requests will come automatically based on your service area.',
        'answer_bn': 'আপনার অবস্থান চালু রাখুন এবং অনলাইনে থাকুন। আপনার সেবা এলাকার ভিত্তিতে অনুরোধ স্বয়ংক্রিয়ভাবে আসবে।'
      },
      {
        'question_en': 'What payment methods are accepted?',
        'question_bn': 'কোন পেমেন্ট পদ্ধতি গ্রহণযোগ্য?',
        'answer_en': 'We accept bKash, Nagad, Rocket, cash, and bank transfers.',
        'answer_bn': 'আমরা বিকাশ, নগদ, রকেট, নগদ এবং ব্যাংক ট্রান্সফার গ্রহণ করি।'
      },
      {
        'question_en': 'How do I update my service area?',
        'question_bn': 'আমি কিভাবে আমার সেবা এলাকা আপডেট করব?',
        'answer_en': 'Go to Settings > Service Area and select your preferred areas in Bangladesh.',
        'answer_bn': 'সেটিংস > সেবা এলাকায় যান এবং বাংলাদেশে আপনার পছন্দের এলাকা নির্বাচন করুন।'
      },
      {
        'question_en': 'What if customer payment is delayed?',
        'question_bn': 'গ্রাহকের পেমেন্ট দেরি হলে কি করব?',
        'answer_en': 'Contact customer first. If no response, report to MechFind support with service details.',
        'answer_bn': 'প্রথমে গ্রাহকের সাথে যোগাযোগ করুন। কোন সাড়া না পেলে, সেবার বিস্তারিত সহ MechFind সাপোর্টে রিপোর্ট করুন।'
      },
      {
        'question_en': 'How to handle emergency calls?',
        'question_bn': 'জরুরি কল কিভাবে সামলাবেন?',
        'answer_en': 'Emergency requests are marked with red color. Accept quickly and inform customer about arrival time.',
        'answer_bn': 'জরুরি অনুরোধগুলি লাল রঙে চিহ্নিত। দ্রুত গ্রহণ করুন এবং গ্রাহককে পৌঁছানোর সময় জানান।'
      }
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.languageCode == 'en' ? 'Help & Support' : 'সাহায্য ও সহায়তা'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              final faq = faqs[index];
              return ExpansionTile(
                title: Text(
                  context.locale.languageCode == 'en' 
                    ? faq['question_en']! 
                    : faq['question_bn']!,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      context.locale.languageCode == 'en' 
                        ? faq['answer_en']! 
                        : faq['answer_bn']!,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.locale.languageCode == 'en' ? 'Close' : 'বন্ধ'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySecurity() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.locale.languageCode == 'en' ? 'Privacy & Security' : 'গোপনীয়তা ও নিরাপত্তা'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  context.locale.languageCode == 'en' 
                    ? 'OTP for Unknown Login' 
                    : 'অজানা লগইনের জন্য OTP',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  context.locale.languageCode == 'en'
                    ? 'Receive OTP when logging from new device'
                    : 'নতুন ডিভাইস থেকে লগইন করার সময় OTP পান',
                  style: TextStyle(fontSize: 12),
                ),
                value: otpForUnknownLogin,
                onChanged: (value) {
                  setDialogState(() {
                    otpForUnknownLogin = value;
                  });
                  setState(() {
                    otpForUnknownLogin = value;
                  });
                  _saveSettings();
                },
              ),
              SwitchListTile(
                title: Text(
                  context.locale.languageCode == 'en' 
                    ? 'Two-Factor Authentication' 
                    : 'দ্বি-ফ্যাক্টর প্রমাণীকরণ',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  context.locale.languageCode == 'en'
                    ? 'Extra security with SMS verification'
                    : 'SMS যাচাইকরণের সাথে অতিরিক্ত নিরাপত্তা',
                  style: TextStyle(fontSize: 12),
                ),
                value: twoFactorAuth,
                onChanged: (value) {
                  setDialogState(() {
                    twoFactorAuth = value;
                  });
                  setState(() {
                    twoFactorAuth = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.locale.languageCode == 'en' ? 'Close' : 'বন্ধ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMiscellaneousInfo() {
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    String selectedBloodGroup = 'A+';
    String secondaryContact = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.locale.languageCode == 'en' ? 'Miscellaneous Info' : 'বিবিধ তথ্য'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: context.locale.languageCode == 'en' ? 'Blood Group' : 'রক্তের গ্রুপ',
                  border: OutlineInputBorder(),
                ),
                value: selectedBloodGroup,
                items: bloodGroups.map((group) => DropdownMenuItem(
                  value: group,
                  child: Text(group),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedBloodGroup = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: context.locale.languageCode == 'en' ? 'Secondary Contact' : 'দ্বিতীয় যোগাযোগ',
                  hintText: context.locale.languageCode == 'en' ? 'e.g., +880171234567' : 'যেমন, +৮৮০১৭১২৩৪৫৬৭',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) {
                  secondaryContact = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.locale.languageCode == 'en' ? 'Cancel' : 'বাতিল'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('blood_group', selectedBloodGroup);
                await prefs.setString('secondary_contact', secondaryContact);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.locale.languageCode == 'en' 
                      ? 'Information saved' 
                      : 'তথ্য সংরক্ষিত হয়েছে'),
                  ),
                );
              },
              child: Text(context.locale.languageCode == 'en' ? 'Save' : 'সংরক্ষণ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceAreaSelection() {
    final bangladeshiCities = [
      'ঢাকা, বাংলাদেশ',
      'চট্টগ্রাম, বাংলাদেশ', 
      'সিলেট, বাংলাদেশ',
      'রাজশাহী, বাংলাদেশ',
      'খুলনা, বাংলাদেশ',
      'বরিশাল, বাংলাদেশ',
      'রংপুর, বাংলাদেশ',
      'ময়মনসিংহ, বাংলাদেশ',
      'কুমিল্লা, বাংলাদেশ',
      'নারায়ণগঞ্জ, বাংলাদেশ',
      'গাজীপুর, বাংলাদেশ',
      'সাভার, বাংলাদেশ',
      'জেসোর, বাংলাদেশ',
      'দিনাজপুর, বাংলাদেশ',
      'বগুড়া, বাংলাদেশ'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.languageCode == 'en' ? 'Select Service Area' : 'সেবা এলাকা নির্বাচন'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: bangladeshiCities.length,
            itemBuilder: (context, index) {
              final city = bangladeshiCities[index];
              return RadioListTile<String>(
                title: Text(city),
                value: city,
                groupValue: selectedServiceArea,
                onChanged: (value) {
                  setState(() {
                    selectedServiceArea = value!;
                  });
                  _saveSettings();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.locale.languageCode == 'en' 
                        ? 'Service area updated to $value' 
                        : 'সেবা এলাকা $value তে আপডেট হয়েছে'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.locale.languageCode == 'en' ? 'Cancel' : 'বাতিল'),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Language' : 'ভাষা'),
          _buildLanguageSelector(),
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
          _buildClickableListItem(
            context.locale.languageCode == 'en' ? 'Service Area' : 'সেবা এলাকা',
            context.locale.languageCode == 'en' 
              ? 'Currently: ${selectedServiceArea.split(',')[0]}' 
              : 'বর্তমান: ${selectedServiceArea.split(',')[0]}',
            _showServiceAreaSelection
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Account' : 'অ্যাকাউন্ট'),
          _buildClickableListItem(
            context.locale.languageCode == 'en' ? 'Miscellaneous Info' : 'বিবিধ তথ্য',
            context.locale.languageCode == 'en' ? 'Blood group, secondary contact' : 'রক্তের গ্রুপ, দ্বিতীয় যোগাযোগ',
            _showMiscellaneousInfo
          ),
          _buildClickableListItem(
            context.locale.languageCode == 'en' ? 'Privacy & Security' : 'গোপনীয়তা ও নিরাপত্তা',
            context.locale.languageCode == 'en' ? 'OTP, 2FA settings' : 'OTP, 2FA সেটিংস',
            _showPrivacySecurity
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(context.locale.languageCode == 'en' ? 'Support' : 'সহায়তা'),
          _buildClickableListItem(
            context.locale.languageCode == 'en' ? 'Help & Support' : 'সাহায্য ও সহায়তা',
            context.locale.languageCode == 'en' ? 'FAQs and common questions' : 'সাধারণ জিজ্ঞাসা ও প্রশ্ন',
            _showHelpSupport
          ),
          _buildClickableListItem(
            context.locale.languageCode == 'en' ? 'Contact Support' : 'সহায়তা যোগাযোগ',
            context.locale.languageCode == 'en' ? 'Official contact details' : 'অফিসিয়াল যোগাযোগের তথ্য',
            _showContactSupport
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

  Widget _buildClickableListItem(String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: const Icon(Icons.circle, color: Colors.blue),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.blue),
      onTap: onTap,
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 45,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear(); // Clear all stored user data
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.locale.languageCode == 'en' ? 'Signed out' : 'সাইন আউট হয়েছে')
              )
            );
            Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
          },
          child: Text(context.locale.languageCode == 'en' ? 'Sign Out' : 'সাইন আউট'),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200, // Fixed width (same as sign out)
        height: 45, // Fixed height (same as sign out)
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
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                Text('🇺🇸', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text('English'),
              ],
            ),
            value: 'en',
            groupValue: selectedLanguage,
            onChanged: (value) => _changeLanguage(value!),
            activeColor: Colors.blue,
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          RadioListTile<String>(
            title: Row(
              children: [
                Text('🇧🇩', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text('বাংলা'),
              ],
            ),
            value: 'bn',
            groupValue: selectedLanguage,
            onChanged: (value) => _changeLanguage(value!),
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang_code', languageCode);
    
    final newLocale = Locale(languageCode);
    await context.setLocale(newLocale);
    
    setState(() {
      selectedLanguage = languageCode;
    });
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageCode == 'en' 
            ? 'Language changed to English' 
            : 'ভাষা বাংলায় পরিবর্তিত হয়েছে'
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
