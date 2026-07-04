import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = "";
  bool _isOtpSent = false;

  // STEP 1: Send SMS
  void _sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (e) => print("Auth Failed: ${e.message}"),
      codeSent: (String verId, int? resendToken) {
        setState(() {
          _verificationId = verId;
          _isOtpSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verId) {},
    );
  }

  // STEP 2: Verify OTP
  void _verifyOtp() async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otpController.text.trim(),
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    print("User Signed In Successfully!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HALO Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone (e.g. +91...)"),
              keyboardType: TextInputType.phone,
            ),
            if (_isOtpSent)
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: "Enter 6-digit OTP"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
              child: Text(_isOtpSent ? "Verify & Login" : "Get OTP"),
            ),
          ],
        ),
      ),
    );
  }
}