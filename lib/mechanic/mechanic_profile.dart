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

class MechanicProfile extends StatefulWidget {
  const MechanicProfile({super.key});

  @override
  State<MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<MechanicProfile> {
  bool isOnline = true;
  File? _profileImage;
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

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
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
              decoration: BoxDecoration(color: AppColors.primary),
            ),
            _buildDrawerItem(Icons.person, 'Edit Profile'),
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
                _buildStatCard('Jobs Today', '5', Icons.work_outline, Colors.blueAccent),
                _buildStatCard('Earnings', '৳120', Icons.attach_money, Colors.orangeAccent),
                _buildStatCard('Next Job', '2:30 PM', Icons.schedule, Colors.purpleAccent),
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
                    onPressed: () {},
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
      onTap: () {},
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
}
