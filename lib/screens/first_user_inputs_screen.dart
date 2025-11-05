// lib/screens/first_user_inputs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FirstUserInputsScreen extends StatefulWidget {
  const FirstUserInputsScreen({super.key});

  @override
  State<FirstUserInputsScreen> createState() => _FirstUserInputsScreenState();
}

class _FirstUserInputsScreenState extends State<FirstUserInputsScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dobController = TextEditingController();

  String _gender = 'Male'; // Default
  String _heightUnit = 'CM'; // Default
  String _weightUnit = 'KG'; // Default
  String _physicalGoal = 'Get Lean and Fit'; // Default
  DateTime? _selectedDob;
  bool _isLoading = false;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final data = <String, dynamic>{
        'gender': _gender,
        'height': _heightController.text.isNotEmpty
            ? double.tryParse(_heightController.text)
            : null,
        'heightUnit': _heightUnit,
        'weight': _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
        'weightUnit': _weightUnit,
        'dob': _selectedDob != null ? Timestamp.fromDate(_selectedDob!) : null,
        'physicalGoal': _physicalGoal,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(data);

      if (mounted) {
        Navigator.pushReplacementNamed(
            context, '/your_gym'); // Stub: Create your_gym_screen.dart later
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Image.asset(
            'assets/images/iron_background.jpg', // your Figma image
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // 60% black overlay
          Container(color: Colors.black.withOpacity(0.6)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We want to know about you',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter below info for us to create the best workout plans based on your needs!',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),

                  // Gender
                  const Text('Gender',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _toggleButton('Male', _gender == 'Male',
                          () => setState(() => _gender = 'Male')),
                      const SizedBox(width: 16),
                      _toggleButton('Female', _gender == 'Female',
                          () => setState(() => _gender = 'Female')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Height
                  const Text('Height',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 176',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _unitButton('CM', _heightUnit == 'CM',
                          () => setState(() => _heightUnit = 'CM')),
                      const SizedBox(width: 8),
                      _unitButton('FT', _heightUnit == 'FT',
                          () => setState(() => _heightUnit = 'FT')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weight
                  const Text('Weight',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'e.g. 59.5',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _unitButton('KG', _weightUnit == 'KG',
                          () => setState(() => _weightUnit = 'KG')),
                      const SizedBox(width: 8),
                      _unitButton('LB', _weightUnit == 'LB',
                          () => setState(() => _weightUnit = 'LB')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DOB
                  const Text('Date of Birth',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 05/12/1983',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Physical Goal
                  const Text('What is your physical goal?',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  _goalOption('Get Lean and Fit'),
                  _goalOption('Loose some Weight'),
                  _goalOption('Build Muscle'),
                  _goalOption('Gain Strength'),
                  const SizedBox(height: 32),

                  // Continue Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Continue →',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('You can always edit this information later',
                        style: TextStyle(color: Colors.orange, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _unitButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget _goalOption(String goal) {
    return GestureDetector(
      onTap: () => setState(() => _physicalGoal = goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _physicalGoal == goal ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
                _physicalGoal == goal
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: _physicalGoal == goal ? Colors.white : Colors.black),
            const SizedBox(width: 16),
            Text(goal,
                style: TextStyle(
                    color: _physicalGoal == goal ? Colors.white : Colors.black,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
