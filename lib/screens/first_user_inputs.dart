import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class FirstUserInputs extends StatefulWidget {
  const FirstUserInputs({super.key});
  @override
  State<FirstUserInputs> createState() => _FirstUserInputsState();
}

class _FirstUserInputsState extends State<FirstUserInputs> {
  final _formKey = GlobalKey<FormState>();
  String _gender = 'Male';
  double _height = 170;
  double _weight = 70;
  String _goal = 'Gain Muscle';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'gender': _gender,
      'height': _height,
      'weight': _weight,
      'goal': _goal,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
          Container(color: const Color(0x80000000)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Complete Your Profile',
                        style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                          labelText: 'Gender',
                          filled: true,
                          fillColor: Colors.white),
                      items: ['Male', 'Female', 'Other']
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _height.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          filled: true,
                          fillColor: Colors.white),
                      onChanged: (v) => _height = double.tryParse(v) ?? 170,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _weight.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          filled: true,
                          fillColor: Colors.white),
                      onChanged: (v) => _weight = double.tryParse(v) ?? 70,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _goal,
                      decoration: const InputDecoration(
                          labelText: 'Goal',
                          filled: true,
                          fillColor: Colors.white),
                      items: [
                        'Gain Muscle',
                        'Lose Fat',
                        'Get Strong',
                        'Stay Fit'
                      ]
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _goal = v!),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.all(16)),
                      child: const Center(
                          child: Text('Start Training →',
                              style: TextStyle(fontSize: 18))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
