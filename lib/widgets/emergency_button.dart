import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 🔔 Trigger light vibration
        HapticFeedback.heavyImpact();

        // 🚨 Show snackbar as before
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Emergency help requested!'),
        ));
      }
      ,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning, color: Colors.white, size: 30),
            SizedBox(width: 12),
            Expanded( // ✅ This prevents overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Emergency Help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to send help signal to nearby mechanics',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                    softWrap: true, // ✅ Ensures the text wraps nicely
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
