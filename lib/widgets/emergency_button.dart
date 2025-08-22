import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'emergency_form_dialog.dart';

class EmergencyButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const EmergencyButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 6,
        minimumSize: const Size.fromHeight(90), // optional
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
      onPressed: onPressed ??
              () {
            HapticFeedback.heavyImpact();
            showDialog(
              context: context,
              builder: (context) => const EmergencyFormDialog(),
            );
          },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 38),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Need Emergency Help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Press this button to send an urgent request to nearby mechanics.\nUse only in true emergencies.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
