import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsScreen extends StatefulWidget {
  final BluetoothCharacteristic? char;
  const ContactsScreen({super.key, this.char});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _ctrl = TextEditingController();
  List<String> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Load contacts from phone memory
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts = prefs.getStringList('sos_contacts') ?? [];
    });
  }

  // Save and Sync logic
  Future<void> _addContact() async {
    String number = _ctrl.text.trim();
    if (number.isEmpty) return;

    // Optional: Add basic phone validation
    if (number.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Add to list and save to memory
    setState(() {
      _contacts.add(number);
    });
    await prefs.setStringList('sos_contacts', _contacts);

    // SYNC TO ESP32: Sends the number over Bluetooth
    if (widget.char != null) {
      try {
        await widget.char!.write(number.codeUnits);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact Added & Synced to ESP32")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved locally, but Sync failed: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved locally (No ESP32 connected)")),
      );
    }

    _ctrl.clear();
  }

  Future<void> _removeContact(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts.removeAt(index);
    });
    await prefs.setStringList('sos_contacts', _contacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Matching your theme
      appBar: AppBar(
        title: const Text("EMERGENCY CONTACTS"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Phone Number (with +91...)",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _addContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("ADD & SYNC CONTACT",
                  style: TextStyle(color: Colors.white)),
            ),
            const Divider(height: 50, color: Colors.white24),
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text("No contacts saved yet",
                          style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          title: Text(_contacts[index],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => _removeContact(index),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
