import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:fl_chart/fl_chart.dart';

// Dummy contact info
final String phoneNumber = '+1 234 567 8901';
final String email = 'mechanic@example.com';
final String address = '123 Main Street, Springfield, USA';

// Dummy achievements
final List<Map<String, String>> achievements = [
  {
    'title': 'Trusted Badge',
    'desc': 'Completed 100 jobs',
    'date': '2025-06-01',
  },
  {
    'title': 'Speedy Service',
    'desc': 'Completed 10 jobs in a week',
    'date': '2025-05-20',
  },
  {
    'title': 'Customer Favorite',
    'desc': 'Received 50 five-star reviews',
    'date': '2025-04-15',
  },
  {
    'title': 'Early Bird',
    'desc': 'Started work before 7:00 AM for 30 days',
    'date': '2025-03-10',
  },
];

// Dummy reviews data
final List<Map<String, dynamic>> dummyReviews = [
  {
    'customerName': 'Alice Johnson',
    'rating': 5,
    'comment': 'Excellent service! Fixed my car quickly and professionally. Highly recommended!',
    'date': '2025-01-15',
    'jobType': 'Brake Repair',
  },
  {
    'customerName': 'Bob Smith',
    'rating': 4,
    'comment': 'Good work on my oil change. Arrived on time and explained everything clearly.',
    'date': '2025-01-10',
    'jobType': 'Oil Change',
  },
  {
    'customerName': 'Sarah Wilson',
    'rating': 5,
    'comment': 'Amazing mechanic! Diagnosed the problem immediately and fixed it at a fair price.',
    'date': '2025-01-08',
    'jobType': 'Engine Diagnostic',
  },
  {
    'customerName': 'Mike Davis',
    'rating': 4,
    'comment': 'Professional service. Fixed my transmission issue efficiently.',
    'date': '2025-01-05',
    'jobType': 'Transmission Repair',
  },
  {
    'customerName': 'Emma Brown',
    'rating': 5,
    'comment': 'Very knowledgeable and honest. Saved me money by suggesting a simple fix.',
    'date': '2025-01-03',
    'jobType': 'Battery Replacement',
  },
  {
    'customerName': 'David Lee',
    'rating': 3,
    'comment': 'Service was okay, but took longer than expected. Work quality was good though.',
    'date': '2024-12-28',
    'jobType': 'Tire Change',
  },
];

class MechanicProfile extends StatefulWidget {
  const MechanicProfile({super.key});

  @override
  State<MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<MechanicProfile> {
  bool isOnline = true;
  File? _profileImage;
  double availableBalance = 1250; // Simulated balance

  // Dummy data for earnings and jobs
  final List<double> weeklyEarnings = [120, 150, 90, 200, 170, 80, 130];
  final List<int> weeklyJobs = [2, 3, 1, 4, 3, 1, 2];
  final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String availableStart = '09:00 AM';
  String availableEnd = '06:00 PM';

  final List<String> timeOptions = [
    '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM'
  ];

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  void _showWithdrawDialog() {
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'Bank';
    final List<String> methods = ['Bank', 'Bkash', 'Credit Card'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (৳)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    selectedMethod = val;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Withdraw Method',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amountText = amountController.text.trim();
                final amount = double.tryParse(amountText);

                if (amount == null || amount <= 0) {
                  _showBanner('Enter a valid amount.');
                  return;
                }

                if (amount > availableBalance) {
                  _showBanner('Insufficient balance.');
                  return;
                }

                Navigator.pop(context);
                _startOtpVerification(amount, selectedMethod);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    // Close the method
  }

  void _startOtpVerification(double amount, String method) {
    final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    final TextEditingController otpController = TextEditingController();

    // Simulate receiving OTP via banner
    _showBanner('Your OTP for withdrawing ৳${amount.toStringAsFixed(0)} is $otp');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter 6-digit OTP',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (otpController.text.trim() == otp) {
                  setState(() {
                    availableBalance -= amount;
                  });
                  Navigator.pop(context);
                  _showBanner('৳${amount.toStringAsFixed(0)} withdrawn from MechFind Account via $method.');
                } else {
                  _showBanner('Incorrect OTP. Please try again.');
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void _showBanner(String message) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: AppColors.primary.withOpacity(0.95),
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAvailabilityDialog() {
    String tempStart = availableStart;
    String tempEnd = availableEnd;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Available Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Start:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: tempStart,
                    items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() { tempStart = val; });
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('End:'),
                  const SizedBox(width: 24),
                  DropdownButton<String>(
                    value: tempEnd,
                    items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() { tempEnd = val; });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  availableStart = tempStart;
                  availableEnd = tempEnd;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
  leading: Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
  ),
  title: Text(
    'Profile',
    style: AppTextStyles.heading.copyWith(color: Colors.white),
  ),
  backgroundColor: AppColors.primary,
  actions: [
    IconButton(
      icon: Icon(Icons.notifications, color: Colors.white),
      onPressed: () {},
    ),
  ],
),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('Zobaer Ali', style: TextStyle(fontFamily: AppFonts.primaryFont)),
              accountEmail: Text('Certified Mechanic', style: TextStyle(fontFamily: AppFonts.secondaryFont)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              decoration: BoxDecoration(color: AppColors.primary),
            ),
            _buildDrawerItem(Icons.star, 'Reviews'),
            _buildDrawerItem(Icons.language, 'Translate'),
            _buildDrawerItem(Icons.logout, 'Logout'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : NetworkImage('https://i.pravatar.cc/150?img=3') as ImageProvider,
                        child: _profileImage == null
                            ? Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.camera_alt, color: AppColors.primary, size: 18),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zobaer Ali', style: AppTextStyles.heading),
                        Text('Certified Mechanic', style: AppTextStyles.label),
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: isOnline,
                      onChanged: (val) => setState(() => isOnline = val),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Contacts Section
            Text('Contacts', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(phoneNumber, style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(email, style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(address, style: AppTextStyles.body)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Achievements Section
            Text('Achievements', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: achievements.map((ach) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified, color: AppColors.accent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ach['title'] ?? '', style: AppTextStyles.heading.copyWith(fontSize: 16)),
                            Text(ach['desc'] ?? '', style: AppTextStyles.body),
                            Text('Achieved on: ${ach['date']}', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 32),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
               Expanded(
      child: _buildStatCard('Jobs Today', '5', Icons.work_outline, Colors.blueAccent),
    ),
    SizedBox(width: 12),
    Expanded(
      child: _buildStatCard('Earnings', '৳120', Icons.attach_money, Colors.orangeAccent),
    ),
    SizedBox(width: 12),
    Expanded(
      child: _buildStatCard('Next Job', '2:30 PM', Icons.schedule, Colors.purpleAccent),
    ),
              ],
            ),
            const SizedBox(height: 32),

            Text('Upcoming Jobs', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildJobCard('Alice Smith', 'Toyota Camry 2019', 'Brake Repair', 'Today 3:00 PM'),
                _buildJobCard('Bob Johnson', 'Honda Accord 2018', 'Oil Change', 'Today 5:00 PM'),
              ],
            ),
            const SizedBox(height: 32),

            Text('Earnings Summary', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Total Earnings (This Month):', style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Text('৳1,250',
                      style: TextStyle(
                        fontSize: FontSizes.heading,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.primaryFont,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 16),
                 ElevatedButton.icon(
  onPressed: _showWithdrawDialog,
  icon: const Icon(Icons.account_balance_wallet),
  label: const Text('Withdraw Balance'),
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 48),
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  ),
)
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Earnings Analytics Section
            Text('Earnings Analytics', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Earnings', style: AppTextStyles.body),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 12, bottom: 8),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (weeklyEarnings.reduce((a, b) => a > b ? a : b)) + 50,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      value % 50 == 0 ? value.toInt().toString() : '',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  return Text(idx >= 0 && idx < weekDays.length ? weekDays[idx] : '', style: TextStyle(fontSize: 12));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(weeklyEarnings.length, (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyEarnings[i],
                                color: AppColors.primary,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Jobs Completed (This Week)', style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(weeklyJobs.length, (i) => FlSpot(i.toDouble(), weeklyJobs[i].toDouble())),
                              isCurved: true,
                              color: AppColors.accent,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      value % 1 == 0 ? value.toInt().toString() : '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  return Transform.rotate(
                                    angle: -0.5,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        idx >= 0 && idx < weekDays.length ? weekDays[idx] : '',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          minY: 0,
                          maxY: (weeklyJobs.reduce((a, b) => a > b ? a : b)).toDouble() + 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text('Manage Availability', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Text(
              'Available Hours: Mon - Sat, $availableStart - $availableEnd',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAvailabilityDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Edit Availability'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
  return ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title, style: TextStyle(fontFamily: AppFonts.secondaryFont)),
    onTap: () {
      Navigator.pop(context); // Close drawer first
      if (title == 'Reviews') {
        _showReviewsDialog();
      } else if (title == 'Translate') {
        _showTranslateDialog();
      } else if (title == 'Logout') {
        _showLogoutDialog();
      }
    },
  );
}

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: FontSizes.subHeading,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildJobCard(String clientName, String carModel, String jobType, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName, style: AppTextStyles.heading.copyWith(fontSize: 18)),
            Text(carModel, style: AppTextStyles.label),
            const SizedBox(height: 4),
            Text('Job: $jobType', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time, style: AppTextStyles.label),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Accept'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showReviewsDialog() {
  // Calculate average rating
  double averageRating = dummyReviews.fold(0.0, (sum, review) => sum + review['rating']) / dummyReviews.length;

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Reviews',
                      style: AppTextStyles.heading.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Summary Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < averageRating.floor() ? Icons.star : 
                              (index < averageRating ? Icons.star_half : Icons.star_border),
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${dummyReviews.length}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Total Reviews',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dummyReviews.length,
                  itemBuilder: (context, index) {
                    final review = dummyReviews[index];
                    return _buildReviewCard(review);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildReviewCard(Map<String, dynamic> review) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['customerName'],
                style: AppTextStyles.heading.copyWith(fontSize: 16),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Job type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              review['jobType'],
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Review comment
          Text(
            review['comment'],
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          
          // Date
          Text(
            review['date'],
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ));
  }

  void _showTranslateDialog() {
    String selectedLanguage = 'English'; // Current language
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Language Settings',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Current Language Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.language, size: 40, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Current Language',
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedLanguage,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Language Options
                    Text(
                      'Select Language',
                      style: AppTextStyles.heading.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    // English Option
                    _buildLanguageOption(
                      'English',
                      '🇺🇸',
                      'Switch to English',
                      selectedLanguage == 'English',
                      () {
                        setState(() {
                          selectedLanguage = 'English';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Bangla Option
                    _buildLanguageOption(
                      'বাংলা (Bangla)',
                      '🇧🇩',
                      'বাংলায় পরিবর্তন করুন',
                      selectedLanguage == 'বাংলা (Bangla)',
                      () {
                        setState(() {
                          selectedLanguage = 'বাংলা (Bangla)';
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showBanner(
                              selectedLanguage == 'English' 
                                ? 'Language changed to English' 
                                : 'ভাষা বাংলায় পরিবর্তিত হয়েছে (Language changed to Bangla)'
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Apply Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOption(String language, String flag, String description, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 16,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to logout?',
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'You will need to login again to access your account.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 18),
                  const SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() {
    // Show logout banner
    _showBanner('Logged out successfully');
    
    // Navigate to login page and clear all previous routes
    Future.delayed(Duration(milliseconds: 1500), () {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login', // Make sure this route exists in your main.dart
        (route) => false, // Remove all previous routes
      );
    });
  }

} // This closes the _MechanicProfileState class