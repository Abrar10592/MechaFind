import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '../utils.dart';

class MechanicSettings extends StatefulWidget {
  final VoidCallback? onBackToProfile;
  
  const MechanicSettings({super.key, this.onBackToProfile});

  @override
  State<MechanicSettings> createState() => _MechanicSettingsState();
}

class _MechanicSettingsState extends State<MechanicSettings> with TickerProviderStateMixin {
  bool pushNotifications = true;
  bool locationAccess = true;
  String selectedLanguage = 'en';
  
  // Service area
  String selectedServiceArea = '';
  
  // Time preferences
  TimeOfDay workStartTime = const TimeOfDay(hour: 9, minute: 0);  // 9:00 AM
  TimeOfDay workEndTime = const TimeOfDay(hour: 18, minute: 0);   // 6:00 PM

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _clearBanner(); // Clear any existing banners
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = context.locale.languageCode;
      // Set default to Bengali name, will be translated for display
      selectedServiceArea = prefs.getString('service_area') ?? 'ঢাকা, বাংলাদেশ';
      
      // Load time preferences
      final startHour = prefs.getInt('work_start_hour') ?? 9;
      final startMinute = prefs.getInt('work_start_minute') ?? 0;
      final endHour = prefs.getInt('work_end_hour') ?? 18;
      final endMinute = prefs.getInt('work_end_minute') ?? 0;
      
      workStartTime = TimeOfDay(hour: startHour, minute: startMinute);
      workEndTime = TimeOfDay(hour: endHour, minute: endMinute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('service_area', selectedServiceArea);
    
    // Save time preferences
    await prefs.setInt('work_start_hour', workStartTime.hour);
    await prefs.setInt('work_start_minute', workStartTime.minute);
    await prefs.setInt('work_end_hour', workEndTime.hour);
    await prefs.setInt('work_end_minute', workEndTime.minute);
  }

  // Helper method to translate service area for display
  String _getTranslatedServiceArea(String serviceArea, bool isEnglish) {
    final cityMap = {
      'Dhaka, Bangladesh': 'ঢাকা, বাংলাদেশ',
      'Chittagong, Bangladesh': 'চট্টগ্রাম, বাংলাদেশ',
      'Sylhet, Bangladesh': 'সিলেট, বাংলাদেশ',
      'Rajshahi, Bangladesh': 'রাজশাহী, বাংলাদেশ',
      'Khulna, Bangladesh': 'খুলনা, বাংলাদেশ',
      'Barisal, Bangladesh': 'বরিশাল, বাংলাদেশ',
      'Rangpur, Bangladesh': 'রংপুর, বাংলাদেশ',
      'Mymensingh, Bangladesh': 'ময়মনসিংহ, বাংলাদেশ',
      'Comilla, Bangladesh': 'কুমিল্লা, বাংলাদেশ',
      'Narayanganj, Bangladesh': 'নারায়ণগঞ্জ, বাংলাদেশ',
      'Gazipur, Bangladesh': 'গাজীপুর, বাংলাদেশ',
      'Savar, Bangladesh': 'সাভার, বাংলাদেশ',
      'Jessore, Bangladesh': 'জেসোর, বাংলাদেশ',
      'Dinajpur, Bangladesh': 'দিনাজপুর, বাংলাদেশ',
      'Bogra, Bangladesh': 'বগুড়া, বাংলাদেশ'
    };

    if (isEnglish) {
      // If current language is English, check if serviceArea is in Bengali, then translate to English
      final englishKey = cityMap.entries
          .firstWhere((entry) => entry.value == serviceArea, 
                     orElse: () => MapEntry(serviceArea, serviceArea))
          .key;
      return englishKey;
    } else {
      // If current language is Bengali, check if serviceArea is in English, then translate to Bengali
      final bengaliValue = cityMap[serviceArea] ?? serviceArea;
      return bengaliValue;
    }
  }

  // Helper methods for launching phone and email
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showBanner('Could not launch phone dialer');
      }
    } catch (e) {
      _showBanner('Error making phone call');
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=MechFind Support Request',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showBanner('Could not launch email app');
      }
    } catch (e) {
      _showBanner('Error opening email app');
    }
  }

  Future<void> _openMaps(double lat, double lng, String placeName) async {
    // Try Google Maps first (most common)
    final googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to generic maps URL
        final fallbackUri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          _showBanner('Could not open maps application');
        }
      }
    } catch (e) {
      _showBanner('Error opening maps');
    }
  }

  void _showLocationOnMap() {
    final isEnglish = context.locale.languageCode == 'en';
    // MechFind office coordinates (Dhanmondi, Dhaka)
    const double officeLat = 23.7465;
    const double officeLng = 90.3760;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEnglish ? 'Office Location' : 'অফিসের অবস্থান',
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              // Map
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: latlng.LatLng(officeLat, officeLng),
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: "https://api.mapbox.com/styles/v1/adil420/cmdkaqq33007y01sj85a2gpa5/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ",
                          additionalOptions: {
                            'accessToken': 'pk.eyJ1IjoiYWRpbDQyMCIsImEiOiJjbWRrN3dhb2wwdXRnMmxvZ2dhNmY2Nzc3In0.yrzJJ09yyfdT4Zg4Y_CJhQ',
                          },
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latlng.LatLng(officeLat, officeLng),
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Address and actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      isEnglish 
                        ? 'House 45, Road 12\nDhanmondi, Dhaka-1209\nBangladesh'
                        : 'বাড়ি ৪৫, রোড ১২\nধানমন্ডি, ঢাকা-১২০৯\nবাংলাদেশ',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openMaps(officeLat, officeLng, 'MechFind Office'),
                      icon: const Icon(Icons.directions),
                      label: Text(isEnglish ? 'Get Directions' : 'দিকনির্দেশ পান'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactSupport() {
    final isEnglish = context.locale.languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.contact_support, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              isEnglish ? 'Contact Support' : 'সহায়তা যোগাযোগ',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.primary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Section
            Row(
              children: [
                Icon(Icons.email_outlined, size: 20, color: AppColors.tealPrimary),
                const SizedBox(width: 8),
                Text(
                  isEnglish ? 'Official Email:' : 'অফিসিয়াল ইমেইল:',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _sendEmail('support@mechfind.com.bd'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      'support@mechfind.com.bd',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Phone Section
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 20, color: AppColors.tealPrimary),
                const SizedBox(width: 8),
                Text(
                  isEnglish ? 'Phone:' : 'ফোন:',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _makePhoneCall('+880-2-9661234'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      '+880-2-9661234',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.green,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.call, size: 16, color: Colors.green),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Address Section
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: AppColors.tealPrimary),
                const SizedBox(width: 8),
                Text(
                  isEnglish ? 'Office Address:' : 'অফিস ঠিকানা:',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    isEnglish 
                      ? 'House 45, Road 12\nDhanmondi, Dhaka-1209\nBangladesh'
                      : 'বাড়ি ৪৫, রোড ১২\nধানমন্ডি, ঢাকা-১২০৯\nবাংলাদেশ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showLocationOnMap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            isEnglish ? 'View on Map' : 'মানচিত্রে দেখুন',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isEnglish ? 'Close' : 'বন্ধ',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    final isEnglish = context.locale.languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text(isEnglish ? 'Select Service Area' : 'সেবা এলাকা নির্বাচন'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showListSelection();
                      },
                      icon: Icon(Icons.list),
                      label: Text(isEnglish ? 'List View' : 'তালিকা'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showMapSelection();
                      },
                      icon: Icon(Icons.map),
                      label: Text(isEnglish ? 'Map View' : 'মানচিত্র'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isEnglish ? 'Cancel' : 'বাতিল'),
          ),
        ],
      ),
    );
  }

  void _showListSelection() {
    final isEnglish = context.locale.languageCode == 'en';
    
    // Bilingual city names - English and Bengali pairs
    final cityMap = {
      'Dhaka, Bangladesh': 'ঢাকা, বাংলাদেশ',
      'Chittagong, Bangladesh': 'চট্টগ্রাম, বাংলাদেশ',
      'Sylhet, Bangladesh': 'সিলেট, বাংলাদেশ',
      'Rajshahi, Bangladesh': 'রাজশাহী, বাংলাদেশ',
      'Khulna, Bangladesh': 'খুলনা, বাংলাদেশ',
      'Barisal, Bangladesh': 'বরিশাল, বাংলাদেশ',
      'Rangpur, Bangladesh': 'রংপুর, বাংলাদেশ',
      'Mymensingh, Bangladesh': 'ময়মনসিংহ, বাংলাদেশ',
      'Comilla, Bangladesh': 'কুমিল্লা, বাংলাদেশ',
      'Narayanganj, Bangladesh': 'নারায়ণগঞ্জ, বাংলাদেশ',
      'Gazipur, Bangladesh': 'গাজীপুর, বাংলাদেশ',
      'Savar, Bangladesh': 'সাভার, বাংলাদেশ',
      'Jessore, Bangladesh': 'জেসোর, বাংলাদেশ',
      'Dinajpur, Bangladesh': 'দিনাজপুর, বাংলাদেশ',
      'Bogra, Bangladesh': 'বগুড়া, বাংলাদেশ'
    };
    
    // Get display names based on current language
    final displayCities = isEnglish 
      ? cityMap.keys.toList() 
      : cityMap.values.toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Select Service Area' : 'সেবা এলাকা নির্বাচন'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: displayCities.length,
            itemBuilder: (context, index) {
              final city = displayCities[index];
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
                      content: Text(isEnglish 
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
            child: Text(isEnglish ? 'Cancel' : 'বাতিল'),
          ),
        ],
      ),
    );
  }

  void _showMapSelection() {
    final isEnglish = context.locale.languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => _ServiceAreaMapDialog(
        isEnglish: isEnglish,
        currentServiceArea: selectedServiceArea,
        onAreaSelected: (area) {
          setState(() {
            selectedServiceArea = area;
          });
          _saveSettings();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEnglish 
                ? 'Service area updated to $area' 
                : 'সেবা এলাকা $area তে আপডেট হয়েছে'),
            ),
          );
        },
      ),
    );
  }

  void _showStartTimePicker() async {
    final isEnglish = context.locale.languageCode == 'en';
    
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: workStartTime,
      helpText: isEnglish ? 'Select Work Start Time' : 'কাজের শুরুর সময় নির্বাচন করুন',
      confirmText: isEnglish ? 'Confirm' : 'নিশ্চিত',
      cancelText: isEnglish ? 'Cancel' : 'বাতিল',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                dayPeriodBorderSide: const BorderSide(color: Colors.grey),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (selectedTime != null) {
      // Validate that start time is before end time
      final startMinutes = selectedTime.hour * 60 + selectedTime.minute;
      final endMinutes = workEndTime.hour * 60 + workEndTime.minute;
      
      if (startMinutes >= endMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish 
              ? 'Start time must be before end time' 
              : 'শুরুর সময় শেষের সময়ের আগে হতে হবে'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        workStartTime = selectedTime;
      });
      _saveSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish 
            ? 'Work start time updated to ${workStartTime.format(context)}' 
            : 'কাজের শুরুর সময় ${workStartTime.format(context)} এ আপডেট হয়েছে'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showEndTimePicker() async {
    final isEnglish = context.locale.languageCode == 'en';
    
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: workEndTime,
      helpText: isEnglish ? 'Select Work End Time' : 'কাজের শেষের সময় নির্বাচন করুন',
      confirmText: isEnglish ? 'Confirm' : 'নিশ্চিত',
      cancelText: isEnglish ? 'Cancel' : 'বাতিল',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                dayPeriodBorderSide: const BorderSide(color: Colors.grey),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (selectedTime != null) {
      // Validate that end time is after start time
      final startMinutes = workStartTime.hour * 60 + workStartTime.minute;
      final endMinutes = selectedTime.hour * 60 + selectedTime.minute;
      
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish 
              ? 'End time must be after start time' 
              : 'শেষের সময় শুরুর সময়ের পরে হতে হবে'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        workEndTime = selectedTime;
      });
      _saveSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish 
            ? 'Work end time updated to ${workEndTime.format(context)}' 
            : 'কাজের শেষের সময় ${workEndTime.format(context)} এ আপডেট হয়েছে'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.locale.languageCode == 'en';
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle hardware back button the same way as AppBar back button
          if (widget.onBackToProfile != null) {
            widget.onBackToProfile!();
          } else {
            // Fallback: try to pop or navigate to profile
            try {
              Navigator.of(context, rootNavigator: false).pop();
            } catch (e) {
              // If pop fails, navigate to profile directly
              Navigator.of(context).pushReplacementNamed('/mechanic/profile');
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            isEnglish ? 'Settings' : 'সেটিংস',
            style: AppTextStyles.heading.copyWith(
              color: Colors.white,
              fontFamily: AppFonts.primaryFont,
            ),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.gradientStart,
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              // Try callback first, then fallback to navigation
              if (widget.onBackToProfile != null) {
                widget.onBackToProfile!();
              } else {
                // Fallback: try to pop or navigate to profile
                try {
                  Navigator.of(context, rootNavigator: false).pop();
                } catch (e) {
                  // If pop fails, navigate to profile directly
                  Navigator.of(context).pushReplacementNamed('/mechanic/profile');
                }
              }
            },
          ),
        ),
        body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Colors.white,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.1 - (_pulseAnimation.value - 1.0),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.tealPrimary.withOpacity(0.06),
                            AppColors.tealPrimary.withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Main content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    // Settings Section
                    _buildModernSectionCard(
                      title: isEnglish ? 'App Settings' : 'অ্যাপ সেটিংস',
                      icon: Icons.settings_outlined,
                      children: [
                        _buildModernToggleItem(
                          title: isEnglish ? 'Push Notifications' : 'পুশ নোটিফিকেশন',
                          subtitle: isEnglish ? 'Receive alerts and updates' : 'সতর্কতা এবং আপডেট পান',
                          icon: Icons.notifications_outlined,
                          value: pushNotifications,
                          onChanged: (value) {
                            setState(() {
                              pushNotifications = value;
                            });
                            // Show banner with appropriate message
                            final message = isEnglish 
                              ? (value ? 'Push Notifications turned ON' : 'Push Notifications turned OFF')
                              : (value ? 'পুশ নোটিফিকেশন চালু করা হয়েছে' : 'পুশ নোটিফিকেশন বন্ধ করা হয়েছে');
                            _showBanner(message, autoHide: true);
                          },
                        ),
                        _buildModernToggleItem(
                          title: isEnglish ? 'Location Access' : 'অবস্থান অ্যাক্সেস',
                          subtitle: isEnglish ? 'Allow location tracking' : 'অবস্থান ট্র্যাকিং অনুমতি দিন',
                          icon: Icons.location_on_outlined,
                          value: locationAccess,
                          onChanged: (value) {
                            setState(() {
                              locationAccess = value;
                            });
                            // Show banner with appropriate message
                            final message = isEnglish 
                              ? (value ? 'Location Access turned ON' : 'Location Access turned OFF')
                              : (value ? 'অবস্থান অ্যাক্সেস চালু করা হয়েছে' : 'অবস্থান অ্যাক্সেস বন্ধ করা হয়েছে');
                            _showBanner(message, autoHide: true);
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Language Section
                    _buildModernSectionCard(
                      title: isEnglish ? 'Language' : 'ভাষা',
                      icon: Icons.language_outlined,
                      children: [
                        _buildModernLanguageSelector(isEnglish),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Work Preferences Section
                    _buildModernSectionCard(
                      title: isEnglish ? 'Work Preferences' : 'কাজের পছন্দ',
                      icon: Icons.work_outline,
                      children: [
                        _buildModernClickableItem(
                          title: isEnglish ? 'Service Area' : 'সেবা এলাকা',
                          subtitle: isEnglish 
                            ? 'Currently: ${_getTranslatedServiceArea(selectedServiceArea, true).split(',')[0]}' 
                            : 'বর্তমান: ${_getTranslatedServiceArea(selectedServiceArea, false).split(',')[0]}',
                          icon: Icons.map_outlined,
                          onTap: _showServiceAreaSelection,
                        ),
                        _buildModernClickableItem(
                          title: isEnglish ? 'Work Start Time' : 'কাজের শুরুর সময়',
                          subtitle: isEnglish 
                            ? 'Starts at: ${workStartTime.format(context)}' 
                            : 'শুরু হয়: ${workStartTime.format(context)}',
                          icon: Icons.schedule_outlined,
                          onTap: _showStartTimePicker,
                        ),
                        _buildModernClickableItem(
                          title: isEnglish ? 'Work End Time' : 'কাজের শেষের সময়',
                          subtitle: isEnglish 
                            ? 'Ends at: ${workEndTime.format(context)}' 
                            : 'শেষ হয়: ${workEndTime.format(context)}',
                          icon: Icons.schedule_outlined,
                          onTap: _showEndTimePicker,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Support Section
                    _buildModernSectionCard(
                      title: isEnglish ? 'Support' : 'সহায়তা',
                      icon: Icons.help_outline,
                      children: [
                        _buildModernClickableItem(
                          title: isEnglish ? 'Help & Support' : 'সাহায্য ও সহায়তা',
                          subtitle: isEnglish ? 'FAQs and common questions' : 'সাধারণ জিজ্ঞাসা ও প্রশ্ন',
                          icon: Icons.quiz_outlined,
                          onTap: _showHelpSupport,
                        ),
                        _buildModernClickableItem(
                          title: isEnglish ? 'Contact Support' : 'সহায়তা যোগাযোগ',
                          subtitle: isEnglish ? 'Get in touch with our team' : 'আমাদের দলের সাথে যোগাযোগ করুন',
                          icon: Icons.contact_support_outlined,
                          onTap: _showContactSupport,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    _buildModernSignOutButton(isEnglish),
                    const SizedBox(height: 16),
                    _buildModernDeleteButton(isEnglish),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // Close Scaffold body
    ), // Close PopScope child (Scaffold)
    ); // Close PopScope
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

  // Modern UI Components
  Widget _buildModernSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.tealPrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily: AppFonts.primaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernToggleItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primary : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: value ? _pulseAnimation.value : 1.0,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.blue,
                  activeTrackColor: Colors.blue.withOpacity(0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernClickableItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.tealPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.tealPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLanguageSelector(bool isEnglish) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _changeLanguage('en'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: selectedLanguage == 'en' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selectedLanguage == 'en' ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '🇺🇸',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'English',
                      style: AppTextStyles.body.copyWith(
                        color: selectedLanguage == 'en' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _changeLanguage('bn'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: selectedLanguage == 'bn' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selectedLanguage == 'bn' ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '🇧🇩',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'বাংলা',
                      style: AppTextStyles.body.copyWith(
                        color: selectedLanguage == 'bn' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSignOutButton(bool isEnglish) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.danger,
                  AppColors.danger.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showSignOutConfirmation(context, isEnglish),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(
                Icons.logout_outlined,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                isEnglish ? 'Sign Out' : 'সাইন আউট',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontFamily: AppFonts.primaryFont,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernDeleteButton(bool isEnglish) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.danger.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _showDeleteConfirmation(context, isEnglish),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: Icon(
          Icons.delete_outline,
          color: AppColors.danger,
          size: 20,
        ),
        label: Text(
          isEnglish ? 'Delete Account' : 'অ্যাকাউন্ট মুছুন',
          style: AppTextStyles.body.copyWith(
            color: AppColors.danger,
            fontFamily: AppFonts.primaryFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context, bool isEnglish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_outlined, color: AppColors.danger),
            const SizedBox(width: 12),
            Text(
              isEnglish ? 'Sign Out' : 'সাইন আউট',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          isEnglish 
            ? 'Are you sure you want to sign out?' 
            : 'আপনি কি নিশ্চিত যে আপনি সাইন আউট করতে চান?',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isEnglish ? 'Cancel' : 'বাতিল',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Add sign out logic here
              Navigator.pushReplacementNamed(context, '/signin');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isEnglish ? 'Sign Out' : 'সাইন আউট',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, bool isEnglish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.danger),
            const SizedBox(width: 12),
            Text(
              isEnglish ? 'Delete Account' : 'অ্যাকাউন্ট মুছুন',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.danger,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          isEnglish 
            ? 'Are you sure you want to delete your account? This action cannot be undone.' 
            : 'আপনি কি নিশ্চিত যে আপনি আপনার অ্যাকাউন্ট মুছতে চান? এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isEnglish ? 'Cancel' : 'বাতিল',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Add delete account logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEnglish 
                      ? 'Account deletion requested' 
                      : 'অ্যাকাউন্ট মুছে ফেলার অনুরোধ করা হয়েছে',
                  ),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isEnglish ? 'Delete' : 'মুছুন',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Banner methods for showing notifications
  void _clearBanner() {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  void _showBanner(String message, {bool autoHide = false, Duration? duration}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: AppColors.primary.withOpacity(0.95),
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              _clearBanner();
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Auto-hide banner for status messages
    if (autoHide) {
      Future.delayed(duration ?? const Duration(seconds: 2), () {
        _clearBanner();
      });
    }
  }
}

class _ServiceAreaMapDialog extends StatefulWidget {
  final bool isEnglish;
  final String currentServiceArea;
  final Function(String) onAreaSelected;

  const _ServiceAreaMapDialog({
    required this.isEnglish,
    required this.currentServiceArea,
    required this.onAreaSelected,
  });

  @override
  State<_ServiceAreaMapDialog> createState() => _ServiceAreaMapDialogState();
}

class _ServiceAreaMapDialogState extends State<_ServiceAreaMapDialog> {
  late String selectedArea;
  final MapController mapController = MapController();

  // City coordinates for Bangladesh
  final Map<String, Map<String, dynamic>> cityData = {
    'Dhaka, Bangladesh': {
      'position': latlng.LatLng(23.8103, 90.4125),
      'bengali': 'ঢাকা, বাংলাদেশ',
      'color': Colors.red,
    },
    'Chittagong, Bangladesh': {
      'position': latlng.LatLng(22.3569, 91.7832),
      'bengali': 'চট্টগ্রাম, বাংলাদেশ',
      'color': Colors.green,
    },
    'Sylhet, Bangladesh': {
      'position': latlng.LatLng(24.8949, 91.8687),
      'bengali': 'সিলেট, বাংলাদেশ',
      'color': Colors.purple,
    },
    'Rajshahi, Bangladesh': {
      'position': latlng.LatLng(24.3745, 88.6042),
      'bengali': 'রাজশাহী, বাংলাদেশ',
      'color': Colors.orange,
    },
    'Khulna, Bangladesh': {
      'position': latlng.LatLng(22.8456, 89.5403),
      'bengali': 'খুলনা, বাংলাদেশ',
      'color': Colors.teal,
    },
    'Barisal, Bangladesh': {
      'position': latlng.LatLng(22.7010, 90.3535),
      'bengali': 'বরিশাল, বাংলাদেশ',
      'color': Colors.brown,
    },
    'Rangpur, Bangladesh': {
      'position': latlng.LatLng(25.7439, 89.2752),
      'bengali': 'রংপুর, বাংলাদেশ',
      'color': Colors.pink,
    },
    'Mymensingh, Bangladesh': {
      'position': latlng.LatLng(24.7471, 90.4203),
      'bengali': 'ময়মনসিংহ, বাংলাদেশ',
      'color': Colors.indigo,
    },
    'Comilla, Bangladesh': {
      'position': latlng.LatLng(23.4607, 91.1809),
      'bengali': 'কুমিল্লা, বাংলাদেশ',
      'color': Colors.amber,
    },
    'Narayanganj, Bangladesh': {
      'position': latlng.LatLng(23.6238, 90.4994),
      'bengali': 'নারায়ণগঞ্জ, বাংলাদেশ',
      'color': Colors.cyan,
    },
    'Gazipur, Bangladesh': {
      'position': latlng.LatLng(23.9999, 90.4203),
      'bengali': 'গাজীপুর, বাংলাদেশ',
      'color': Colors.lime,
    },
    'Savar, Bangladesh': {
      'position': latlng.LatLng(23.8583, 90.2667),
      'bengali': 'সাভার, বাংলাদেশ',
      'color': Colors.deepOrange,
    },
    'Jessore, Bangladesh': {
      'position': latlng.LatLng(23.1667, 89.2167),
      'bengali': 'জেসোর, বাংলাদেশ',
      'color': Colors.blueGrey,
    },
    'Dinajpur, Bangladesh': {
      'position': latlng.LatLng(25.6217, 88.6354),
      'bengali': 'দিনাজপুর, বাংলাদেশ',
      'color': Colors.deepPurple,
    },
    'Bogra, Bangladesh': {
      'position': latlng.LatLng(24.8465, 89.3776),
      'bengali': 'বগুড়া, বাংলাদেশ',
      'color': Colors.tealAccent,
    },
  };

  @override
  void initState() {
    super.initState();
    selectedArea = widget.currentServiceArea;
  }

  String _getDisplayName(String englishName) {
    if (widget.isEnglish) {
      return englishName;
    } else {
      return cityData[englishName]?['bengali'] ?? englishName;
    }
  }

  String _getEnglishName(String displayName) {
    if (widget.isEnglish) {
      return displayName;
    } else {
      // Find English key for Bengali value
      for (var entry in cityData.entries) {
        if (entry.value['bengali'] == displayName) {
          return entry.key;
        }
      }
      return displayName;
    }
  }

  void _onCityTapped(String cityKey) {
    setState(() {
      selectedArea = widget.isEnglish ? cityKey : cityData[cityKey]!['bengali'];
    });

    // Animate to the selected city
    final cityInfo = cityData[cityKey]!;
    mapController.move(cityInfo['position'], 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isEnglish 
                        ? 'Select Service Area on Map' 
                        : 'মানচিত্রে সেবা এলাকা নির্বাচন করুন',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Map
            Expanded(
              flex: 3,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: latlng.LatLng(23.8103, 90.4125), // Dhaka center
                  initialZoom: 7.0,
                  minZoom: 6.0,
                  maxZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: cityData.entries.map((entry) {
                      final cityKey = entry.key;
                      final cityInfo = entry.value;
                      final isSelected = _getEnglishName(selectedArea) == cityKey;
                      
                      return Marker(
                        point: cityInfo['position'],
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _onCityTapped(cityKey),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : cityInfo['color'],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isSelected ? Icons.check : Icons.location_city,
                                color: Colors.white,
                                size: isSelected ? 30 : 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            // City List
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEnglish 
                        ? 'Available Service Areas:' 
                        : 'উপলব্ধ সেবা এলাকা:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: cityData.length,
                        itemBuilder: (context, index) {
                          final cityKey = cityData.keys.elementAt(index);
                          final cityInfo = cityData[cityKey]!;
                          final displayName = _getDisplayName(cityKey);
                          final isSelected = _getEnglishName(selectedArea) == cityKey;
                          
                          return GestureDetector(
                            onTap: () => _onCityTapped(cityKey),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: cityInfo['color'],
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(6),
                                        bottomLeft: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        displayName.split(',')[0], // Show only city name
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        widget.isEnglish ? 'Cancel' : 'বাতিল',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onAreaSelected(selectedArea);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(widget.isEnglish ? 'Confirm' : 'নিশ্চিত করুন'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
