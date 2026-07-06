import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactsScreen extends StatefulWidget {
  final BluetoothCharacteristic? char;
  const ContactsScreen({super.key, this.char});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<Map<String, String>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Get user-specific key
  String _getStorageKey() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? 'sos_contacts_v2_${user.uid}' : 'sos_contacts_v2';
  }

  // Load contacts with legacy data migration fallback
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey();
    List<String> rawList = prefs.getStringList(key) ?? [];

    if (rawList.isEmpty) {
      // Check if we can migrate global/legacy contacts
      List<String> globalV2 = prefs.getStringList('sos_contacts_v2') ?? [];
      if (globalV2.isNotEmpty) {
        setState(() {
          _contacts = globalV2.map((str) {
            try {
              final map = jsonDecode(str);
              return {
                "name": map['name']?.toString() ?? "No Name",
                "phone": map['phone']?.toString() ?? "",
              };
            } catch (e) {
              return {"name": "No Name", "phone": str};
            }
          }).toList();
        });
        await _save();
        // Immediately clear global keys to prevent double migration
        await prefs.remove('sos_contacts_v2');
        await prefs.remove('sos_contacts');
      } else {
        // Check for legacy v1 contacts (which were plain strings)
        List<String> legacyList = prefs.getStringList('sos_contacts') ?? [];
        if (legacyList.isNotEmpty) {
          setState(() {
            _contacts = legacyList
                .map((num) => {"name": "No Name", "phone": num})
                .toList();
          });
          await _save();
          // Immediately clear global keys to prevent double migration
          await prefs.remove('sos_contacts_v2');
          await prefs.remove('sos_contacts');
        } else {
          setState(() {
            _contacts = [];
          });
        }
      }
    } else {
      setState(() {
        _contacts = rawList.map((str) {
          try {
            final map = jsonDecode(str);
            return {
              "name": map['name']?.toString() ?? "No Name",
              "phone": map['phone']?.toString() ?? "",
            };
          } catch (e) {
            return {"name": "No Name", "phone": str};
          }
        }).toList();
      });
    }
  }

  // Save list to device memory in v2 format
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey();
    List<String> rawList = _contacts.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList(key, rawList);
  }

  // Add Contact & Sync Phone to ESP32
  Future<void> _addContact() async {
    String name = _nameCtrl.text.trim();
    String phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      _showSnackBar("Please enter a contact name", isError: true);
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      _showSnackBar("Please enter a valid phone number", isError: true);
      return;
    }

    setState(() {
      _contacts.add({"name": name, "phone": phone});
    });
    await _save();

    // SYNC TO ESP32: Sends only the phone number string codeUnits
    if (widget.char != null) {
      try {
        await widget.char!.write(phone.codeUnits);
        _showSnackBar("Contact Added & Synced to ESP32");
      } catch (e) {
        _showSnackBar("Saved locally, but Sync failed: $e", isError: true);
      }
    } else {
      _showSnackBar("Saved locally (No ESP32 connected)");
    }

    _nameCtrl.clear();
    _phoneCtrl.clear();
  }

  // Edit Contact Dialog (Edits existing/legacy numbers)
  void _editContact(int index) {
    final nameEditCtrl = TextEditingController(text: _contacts[index]['name']);
    final phoneEditCtrl = TextEditingController(text: _contacts[index]['phone']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[950],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Edit Contact",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEditCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneEditCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Phone Number",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              String newName = nameEditCtrl.text.trim();
              String newPhone = phoneEditCtrl.text.trim();

              if (newName.isEmpty || newPhone.isEmpty || newPhone.length < 10) {
                _showSnackBar("Please fill in a valid name and number",
                    isError: true);
                return;
              }

              setState(() {
                _contacts[index] = {"name": newName, "phone": newPhone};
              });
              await _save();

              // Sync to ESP32 if connected
              if (widget.char != null) {
                try {
                  await widget.char!.write(newPhone.codeUnits);
                } catch (e) {
                  debugPrint("Edit sync failed: $e");
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
                _showSnackBar("Contact Updated Successfully");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Remove Contact
  Future<void> _removeContact(int index) async {
    setState(() {
      _contacts.removeAt(index);
    });
    await _save();
    _showSnackBar("Contact Deleted");
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "EMERGENCY CONTACTS",
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Name Field
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline_rounded,
                    color: Colors.blueAccent),
                labelText: "Contact Name",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Field
            TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_iphone_rounded,
                    color: Colors.blueAccent),
                labelText: "Phone Number (with +91...)",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _addContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 5,
                shadowColor: Colors.blueAccent.withOpacity(0.3),
              ),
              child: const Text(
                "ADD & SYNC CONTACT",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
            ),
            const Divider(height: 50, color: Colors.white24),

            // List of Contacts
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text("No contacts saved yet",
                          style: TextStyle(color: Colors.white54, fontSize: 16)))
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.05), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          title: Text(
                            _contacts[index]['name'] ?? 'No Name',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _contacts[index]['phone'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blueAccent),
                                onPressed: () => _editContact(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () => _removeContact(index),
                              ),
                            ],
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
