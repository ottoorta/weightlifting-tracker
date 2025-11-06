// lib/widgets/workout_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkoutCard extends StatefulWidget {
  const WorkoutCard({super.key});
  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  bool _isTomorrow = false;
  Map<String, dynamic>? _workout;
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  @override
  Widget build(BuildContext context) {
    if (_workout == null || _exercises.isEmpty) {
      return _buildEmptyCard();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Your Next Workout",
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Text("${_workout!['duration']} min • ${_exercises.length} exercises",
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow),
            label: const Text("Start Workout"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24), // Reduced from 32
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // THIS FIXES OVERFLOW
        children: [
          const Icon(Icons.fitness_center, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text("No workout yet!",
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text("Tap below to get your first FREE Auto Coach workout!",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _generateFreeWorkout(uid),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_isLoading ? "Generating..." : "Get FREE Workout!",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWorkout() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: today) // exact today
        .orderBy('createdAt', descending: true) // newest first
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _workout = null;
        _exercises = [];
      });
      return;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final exerciseIds = (data['exerciseIds'] as List<dynamic>?) ?? [];

    // ——— REAL EXERCISES ———
    // QUICK TEST: grab 3 real ones from your DB
    final realIds = [
      'O8YBbe94sar78wiYGu1d',
      'kYd0K897PFjYdPy1Ept5',
      'oOtrzdycQJaQf1U7sFrs'
    ]; // ← change to YOUR real IDs
    final exerciseDocs = await Future.wait(
      realIds.map((id) =>
          FirebaseFirestore.instance.collection('exercises').doc(id).get()),
    );

    final exercises =
        exerciseDocs.where((d) => d.exists).map((d) => d.data()!).toList();

    setState(() {
      _workout = {
        ...data,
        'duration': 59,
        'coach': 'Auto Coach',
      };
      _exercises = exercises;
    });
  }

  Future<void> _generateFreeWorkout(String uid) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final used = (userDoc.data()?['freeWorkoutsUsed'] ?? 0) as int;

      if (used >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No more free workouts!")),
        );
        Navigator.pushNamed(context, '/subscriptions');
        return;
      }

      // ——— ADD A TIMESTAMP SO WE CAN SORT ———
      await FirebaseFirestore.instance.collection('workouts').add({
        'uid': uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'duration': 59,
        'coach': 'Auto Coach',
        'coachPhoto': 'https://i.imgur.com/5K8zK5P.png',
        'exerciseIds': [
          'O8YBbe94sar78wiYGu1d',
          'kYd0K897PFjYdPy1Ept5',
          'oOtrzdycQJaQf1U7sFrs'
        ], // ← REAL IDs
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'freeWorkoutsUsed': used + 1,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Workout Generated!"), backgroundColor: Colors.green),
      );

      // THIS WILL NOW SHOW THE FRESH ONE
      await _loadWorkout();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
