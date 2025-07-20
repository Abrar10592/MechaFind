import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'emergency_form_dialog.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        icon: const Icon(Icons.warning, color: Colors.white, size: 30),
        label: const Text(
          "Need Emergency Help?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          HapticFeedback.heavyImpact();
          showDialog(
            context: context,
            builder: (context) => const EmergencyFormDialog(),
          );
        },
      ),
    );
  }
}
