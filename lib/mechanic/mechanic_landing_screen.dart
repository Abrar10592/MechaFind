import 'package:flutter/material.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/data/demo_data.dart';
import 'package:mechfind/widgets/sos_card.dart';

class MechanicLandingScreen extends StatefulWidget {
  const MechanicLandingScreen({super.key});

  @override
  State<MechanicLandingScreen> createState() => _MechanicLandingScreenState();
}

class _MechanicLandingScreenState extends State<MechanicLandingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2.0,
        title: const Text(
          'Mechanic Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: FontSizes.heading,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard("12", "Completed Today")),
                SizedBox(width: 10),
                Expanded(child: _buildStatCard("2", "Active Request")),
                SizedBox(width: 10),
                Expanded(child: _buildStatCard("4.8", "Rating")),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Active SOS Signals",
              style: TextStyle(
                color: const Color.fromARGB(255, 43, 46, 48),
                fontSize: 20,
                fontFamily: AppFonts.primaryFont,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: demoData.length,
                itemBuilder: (context, index) {
                  final request = demoData[index];
                  return Sos_Card(request: request);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(255, 249, 250, 250),
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(7.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  color: const Color.fromARGB(255, 0, 99, 180),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color.fromARGB(255, 60, 62, 65),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
