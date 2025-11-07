// lib/screens/workout_card.dart
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

  Future<void> _loadWorkout() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: uid)
        .orderBy('date')
        .limit(_isTomorrow ? 2 : 1)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _workout = null; // THIS MAKES BUTTON APPEAR
        _exercises = [];
      });
      return;
    }

    final doc = snapshot.docs[_isTomorrow ? 1 : 0];
    final data = doc.data();
    final exerciseIds = data['exerciseIds'] as List<dynamic>? ?? [];

    final exerciseDocs = await Future.wait(exerciseIds.map((id) =>
        FirebaseFirestore.instance
            .collection('exercises')
            .doc(id.toString())
            .get()));

    final exercises = exerciseDocs
        .where((doc) => doc.exists)
        .map((doc) => doc.data()!)
        .toList();

    setState(() {
      _workout = data;
      _exercises = exercises;
    });
  }

  String _title() => _isTomorrow ? "Tomorrow's Workout" : "Your Next Workout";

  @override
  Widget build(BuildContext context) {
    if (_workout == null || _exercises.isEmpty) {
      return _buildEmptyCard();
    }

    final muscleMap = _calcMuscleDistribution(_exercises);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/workout_main'),
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // TITLE
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _title(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),

            // EXERCISE IMAGES
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _exercises.length,
                itemBuilder: (ctx, i) {
                  final ex = _exercises[i];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(ex['imageUrl'] ??
                            'https://i.imgur.com/5K8zK5P.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // MUSCLE %
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: muscleMap.entries
                    .map((e) => Chip(
                          backgroundColor: Colors.orange,
                          label: Text("${e.key} ${e.value}%",
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 12),

            // DURATION + COACH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "${_workout!['duration']} min, ${_exercises.length} exercises",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  _buildCoachBadge(),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(Icons.refresh, "Regenerate", _regenerate),
                _actionBtn(Icons.skip_next, _isTomorrow ? "Previous" : "Next",
                    () {
                  setState(() => _isTomorrow = !_isTomorrow);
                  _loadWorkout();
                }),
                _actionBtn(Icons.edit, "Edit",
                    () => Navigator.pushNamed(context, '/workout_main')),
                _actionBtn(Icons.favorite_border, "Favorite", _favorite),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _generateFreeWorkout(String uid) async {
    setState(() => _isLoading = true);
    try {
      // 1. Check if user has free workouts left
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final used = userDoc['freeWorkoutsUsed'] ?? 0;
      if (used >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("No more free workouts! Subscribe for more.")),
        );
        Navigator.pushNamed(context, '/subscriptions');
        return;
      }

      // 2. Generate dummy workout
      final workout = {
        'uid': uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'duration': 59,
        'coach': 'Auto Coach',
        'coachPhoto': 'https://i.imgur.com/5K8zK5P.png',
        'exerciseIds': ['abc123', 'def456', 'ghi789'], // your exercise IDs
      };

      await FirebaseFirestore.instance.collection('workouts').add(workout);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'freeWorkoutsUsed': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Workout Generated!"), backgroundColor: Colors.green),
      );

      _loadWorkout(); // Reload card
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed. Try again.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildEmptyCard() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.fitness_center, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            "No workout yet!",
            style: TextStyle(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap below to get your first FREE Auto Coach workout!",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachBadge() {
    final coach = _workout!['coach'] ?? 'You';
    final isPro = coach == 'Pro Coach';
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(
              _workout!['coachPhoto'] ?? 'https://i.imgur.com/5K8zK5P.png'),
        ),
        const SizedBox(width: 8),
        Text(coach, style: const TextStyle(color: Colors.white)),
        if (isPro) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.orange),
            onPressed: () => Navigator.pushNamed(context, '/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange),
            onPressed: () => Navigator.pushNamed(context, '/workout_main'),
          ),
        ],
      ],
    );
  }

  Map<String, int> _calcMuscleDistribution(
      List<Map<String, dynamic>> exercises) {
    final map = <String, int>{};
    for (var ex in exercises) {
      final muscles = ex['muscles'] as List<dynamic>? ?? [];
      for (var m in muscles) {
        map[m] = (map[m] ?? 0) + 1;
      }
    }
    final total = map.values.fold(0, (a, b) => a + b);
    return map.map(
        (k, v) => MapEntry(k, total == 0 ? 0 : ((v / total) * 100).round()));
  }

  void _regenerate() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Regenerating...")));
  }

  void _favorite() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Saved to Favorites!")));
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      icon: Icon(icon, color: Colors.orange),
      label: Text(label, style: const TextStyle(color: Colors.orange)),
      onPressed: onTap,
    );
  }
}
