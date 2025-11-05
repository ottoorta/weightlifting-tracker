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

    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': user.email,
      'name': user.displayName ?? 'Iron Warrior',
      'photoURL': user.photoURL,
      'gender': _gender,
      'height': _height,
      'weight': _weight,
      'goal': _goal,
      'level': 'beginner',
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
          Image.asset('assets/images/splash_bg.jpg',
              fit: BoxFit.cover, height: double.infinity),
          Container(color: const Color(0x80000000)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome!',
                        style: TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const Text('3 quick questions',
                        style: TextStyle(fontSize: 18, color: Colors.white70)),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                          labelText: 'Gender',
                          filled: true,
                          fillColor: Colors.white),
                      items: ['Male', 'Female', 'Other']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: '170',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          filled: true,
                          fillColor: Colors.white),
                      onChanged: (v) => _height = double.tryParse(v) ?? 170,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: '70',
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
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _goal = v!),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.all(18)),
                        child: const Text('CREATE MY PLAN →',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
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
