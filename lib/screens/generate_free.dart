// lib/screens/generate_free.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GenerateFreeWorkoutScreen extends StatefulWidget {
  @override
  State<GenerateFreeWorkoutScreen> createState() =>
      _GenerateFreeWorkoutScreenState();
}

class _GenerateFreeWorkoutScreenState extends State<GenerateFreeWorkoutScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateWorkout();
  }

  Future<void> _generateWorkout() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ids = await _getRandomIds();
    await FirebaseFirestore.instance.collection('workouts').add({
      'uid': uid,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'duration': 59,
      'coach': 'Auto Coach',
      'coachPhoto': 'https://i.imgur.com/5K8zK5P.png',
      'exerciseIds': ids,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<List<String>> _getRandomIds() async {
    final snap = await FirebaseFirestore.instance
        .collection('exercises')
        .where('isAvailable', isEqualTo: true)
        .get();
    final docs = snap.docs..shuffle();
    return docs.take(5).map((d) => d.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 20),
            const Text("Generating your FREE workout...",
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
