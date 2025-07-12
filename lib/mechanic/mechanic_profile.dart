import 'package:flutter/material.dart';

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
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // TODO: Open notifications
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('John Doe'),
              accountEmail: Text('Mechanic'),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Edit Profile'),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Status Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage:
                          NetworkImage('https://i.pravatar.cc/150?img=3'),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zobaer Ali',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Certified Mechanic',
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    Text(isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold)),
                    Switch(
                      value: isOnline,
                      onChanged: (val) {
                        setState(() {
                          isOnline = val;
                        });
                      },
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                )
              ],
            ),

            SizedBox(height: 24),

            // Today’s Overview Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Jobs Today', '5', Icons.work_outline,
                    Colors.blueAccent),
                _buildStatCard('Earnings', '\$120', Icons.attach_money,
                    Colors.orangeAccent),
                _buildStatCard(
                    'Next Job', '2:30 PM', Icons.schedule, Colors.purpleAccent),
              ],
            ),

            SizedBox(height: 32),

            // Upcoming Jobs List Header
            Text('Upcoming Jobs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            SizedBox(height: 12),

            // Upcoming Jobs List
            ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildJobCard(
                    clientName: 'Alice Smith',
                    carModel: 'Toyota Camry 2019',
                    jobType: 'Brake Repair',
                    time: 'Today 3:00 PM'),
                _buildJobCard(
                    clientName: 'Bob Johnson',
                    carModel: 'Honda Accord 2018',
                    jobType: 'Oil Change',
                    time: 'Today 5:00 PM'),
              ],
            ),

            SizedBox(height: 32),

            // Earnings Summary
            Text('Earnings Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Total Earnings (This Month):',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('\$1,250',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Withdraw balance action
                    },
                    icon: Icon(Icons.account_balance_wallet),
                    label: Text('Withdraw Balance'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                  )
                ],
              ),
            ),

            SizedBox(height: 32),

            // Availability Schedule Section (Simple)
            Text('Manage Availability',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              'Available Hours: Mon - Sat, 9:00 AM - 6:00 PM',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // TODO: Open availability settings
              },
              child: Text('Edit Availability'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildJobCard(
      {required String clientName,
      required String carModel,
      required String jobType,
      required String time}) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(carModel, style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 4),
            Text('Job: $jobType'),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time, style: TextStyle(color: Colors.grey[600])),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Accept job logic
                      },
                      child: Text('Accept'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Cancel job logic
                      },
                      child: Text('Cancel', style: TextStyle(color: Colors.red)),
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