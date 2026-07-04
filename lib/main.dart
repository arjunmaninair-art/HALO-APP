import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'contacts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const HaloApp());
}

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const BluetoothAndSOSPage(),
    );
  }
}

class BluetoothAndSOSPage extends StatefulWidget {
  const BluetoothAndSOSPage({super.key});
  @override
  State<BluetoothAndSOSPage> createState() => _BluetoothAndSOSPageState();
}

class _BluetoothAndSOSPageState extends State<BluetoothAndSOSPage> {
  BluetoothCharacteristic? targetChar;
  String _status = "Scanning...";
  bool _isConnected = false;
  bool _isSending = false;
  bool _isSosActive = false;
  Timer? _trackingTimer;
  final Telephony telephony = Telephony.instance;

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == 'ESP32_SOS_Button') _connect(r.device);
        }
      });
    } catch (e) {
      debugPrint("Bluetooth Scan Error: $e");
      setState(() {
        _status = "Bluetooth Off / Error";
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var c in s.characteristics) {
            if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              targetChar = c;
              await c.setNotifyValue(true);
              c.onValueReceived.listen((val) {
                if (String.fromCharCodes(val).trim() == "<01x0A>")
                  _triggerSOS();
              });
              setState(() {
                _status = "Device Linked";
                _isConnected = true;
              });
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _status = "Disconnected";
        _isConnected = false;
      });
    }
  }

  Future<void> _triggerSOS() async {
    if (_isSosActive) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _isSosActive = true;
      _isSending = true;
    });

    try {
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

      if (permissionsGranted == true) {
        final prefs = await SharedPreferences.getInstance();
        List<String> phoneList =
            prefs.getStringList('sos_contacts') ?? ["8714992152"];

        // 1. Get High Accuracy Location with Timeout Fallback
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          );
        } catch (e) {
          pos = await Geolocator.getLastKnownPosition();
        }

        // 1.5 Clear the history node from the database for a fresh tracking session
        try {
          await FirebaseDatabase.instance.ref("active_incidents/sos_device/history").remove();
        } catch (dbError) {
          debugPrint("Database clear error: $dbError");
        }

        // 2. Send initial write to Database first
        try {
          await _updateLocationInDatabase(pos, true);
        } catch (dbError) {
          debugPrint("Database initial write error: $dbError");
        }



        // 3. Construct Live Web Tracking Link
        String mapsUrl = pos != null
            ? "https://halo-safety.web.app/map.html?device=sos_device&lat=${pos.latitude}&lng=${pos.longitude}"
            : "https://halo-safety.web.app/map.html?device=sos_device";
        String message = "🚨 HALO SOS! Help me. Live Satellite Track: $mapsUrl";

        // 4. Send SMS to all contacts sequentially
        for (String number in phoneList) {
          debugPrint("Attempting SMS to: $number");
          await telephony.sendSms(
            to: number,
            message: message,
            isMultipart: true, // Crucial for long links
          );

          // Safety delay for Android SMS Manager
          await Future.delayed(const Duration(seconds: 2));
        }

        // 5. Start periodic tracking every 10 seconds
        _trackingTimer =
            Timer.periodic(const Duration(seconds: 10), (timer) async {
          if (!_isSosActive) {
            timer.cancel();
            return;
          }
          Position? currentPos;
          try {
            currentPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 6),
            );
          } catch (e) {
            currentPos = await Geolocator.getLastKnownPosition();
          }
          await _updateLocationInDatabase(currentPos, true);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "SOS triggered & sent to ${phoneList.length} contacts")),
          );
        }
      }
    } catch (e) {
      debugPrint("SOS Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _updateLocationInDatabase(Position? pos, bool isActive) async {
    try {
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("active_incidents/sos_device");

      if (isActive) {
        // Always set is_active to true when the emergency is active
        Map<String, dynamic> updates = {
          "is_active": true,
        };
        if (pos != null) {
          updates["lat"] = pos.latitude;
          updates["lng"] = pos.longitude;
          updates["timestamp"] = DateTime.now().millisecondsSinceEpoch;
        }
        await ref.update(updates);

        // Push a new entry to the breadcrumb history only if we have a valid position
        if (pos != null) {
          DatabaseReference historyRef = ref.child("history").push();
          await historyRef.set({
            "lat": pos.latitude,
            "lng": pos.longitude,
            "timestamp": DateTime.now().millisecondsSinceEpoch,
          });
        }
      } else {
        // Set is_active to false when stopping
        await ref.update({
          "is_active": false,
        });
        // We do not clear the history here so the trail is preserved!
      }
      debugPrint("Firebase database write successful! is_active: $isActive");
    } catch (dbError) {
      debugPrint("Firebase Database Error: $dbError");
    }
  }

  Future<void> _stopSOS() async {
    HapticFeedback.mediumImpact();
    _trackingTimer?.cancel();
    setState(() {
      _isSosActive = false;
      _isSending = false;
    });

    // Write is_active = false to database
    await _updateLocationInDatabase(null, false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SOS Alert Stopped")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.15)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text("HALO",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white)),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            _isConnected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_searching,
                            color: _isConnected
                                ? Colors.cyanAccent
                                : Colors.orangeAccent),
                        const SizedBox(width: 15),
                        Text(_status,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        const Spacer(),
                        if (!_isConnected)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onLongPress: _isSosActive ? _stopSOS : _triggerSOS,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isSosActive
                              ? [Colors.red.shade900, Colors.red.shade600]
                              : [
                                  Colors.blue.shade700,
                                  Colors.purple.shade600,
                                  Colors.red.shade600
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 10)
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.black),
                        child: Center(
                          child: _isSending
                              ? const CircularProgressIndicator(
                                  color: Colors.redAccent)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_isSosActive ? "ACTIVE" : "SOS",
                                        style: TextStyle(
                                            fontSize: _isSosActive ? 36 : 48,
                                            fontWeight: FontWeight.w900,
                                            color: _isSosActive
                                                ? Colors.redAccent
                                                : Colors.white)),
                                    Text(
                                        _isSosActive
                                            ? "HOLD TO CANCEL"
                                            : "HOLD TO SEND",
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white54,
                                            letterSpacing: 2)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          icon: Icons.people_alt_rounded,
                          label: "Contacts",
                          color: Colors.blueAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) =>
                                      ContactsScreen(char: targetChar))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionButton(
                            icon: Icons.map_rounded,
                            label: "Safe Zones",
                            color: Colors.greenAccent,
                            onTap: () {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
