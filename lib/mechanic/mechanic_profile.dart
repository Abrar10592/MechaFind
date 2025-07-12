import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';

class MechanicProfile extends StatefulWidget {
  const MechanicProfile({super.key});

  @override
  State<MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<MechanicProfile> {
  bool isOnline = true;

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
              accountName: Text('John Doe', style: TextStyle(fontFamily: AppFonts.primaryFont)),
              accountEmail: Text('Mechanic', style: TextStyle(fontFamily: AppFonts.secondaryFont)),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
              decoration: BoxDecoration(color: AppColors.primary),
            ),
            _buildDrawerItem(Icons.person, 'Edit Profile'),
            _buildDrawerItem(Icons.settings, 'Settings'),
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
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
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
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Jobs Today', '5', Icons.work_outline, Colors.blueAccent),
                _buildStatCard('Earnings', '\$120', Icons.attach_money, Colors.orangeAccent),
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
                  Text('\$1,250',
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
            Text('Manage Availability', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            Text(
              'Available Hours: Mon - Sat, 9:00 AM - 6:00 PM',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {},
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
