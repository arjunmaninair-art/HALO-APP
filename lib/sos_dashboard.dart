import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // 1. Added Firebase Realtime Database import

class SosDashboard extends StatefulWidget {
  const SosDashboard({super.key});

  @override
  State<SosDashboard> createState() => _SosDashboardState();
}

class _SosDashboardState extends State<SosDashboard> {
  // Your original function that prints to the console
  void _handleSosTrigger() {
    debugPrint("SOS Button Pressed!");
    // TODO: Add your location and SMS sending logic here
  }

  // 2. Added the Firebase Network Verification Function
  Future<void> testFirebaseConnection() async {
    try {
      // Points to a path inside your specific database console instance
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("active_incidents/test_device");

      await ref.set({
        "is_active": true,
        "lat": 10.0104,
        "lng": 76.3608,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint("Database write successful!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Firebase Connected Successfully! Check your console."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error writing to database: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Database Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("HALO DASHBOARD"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "ARE YOU IN DANGER?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // YOUR ORIGINAL SOS DESIGN
            GestureDetector(
              onTap: _handleSosTrigger,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "SOS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),

            // 3. New Blue Test Button Added Beneath Your Layout Elements
            ElevatedButton.icon(
              onPressed: testFirebaseConnection,
              icon: const Icon(Icons.cloud_done),
              label: const Text("Test Firebase Connection"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
