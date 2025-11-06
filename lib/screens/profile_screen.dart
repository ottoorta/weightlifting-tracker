// lib/screens/profile_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Account", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text("Logout", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ),
    );
  }
}
