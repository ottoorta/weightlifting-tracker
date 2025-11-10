// lib/widgets/workout_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _navigateToWorkoutMain() {
    Navigator.pushNamed(context, '/workout_main', arguments: {
      'workout': _workout!,
      'exercises': _exercises,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_workout == null) return _buildEmptyCard();

    final muscleMap = <String, double>{};
    for (var ex in _exercises) {
      final muscles = ex['muscles'] as List<dynamic>? ?? [];
      final percentages = ex['muscleDistribution'] as List<dynamic>? ?? [];
      for (int i = 0; i < muscles.length && i < percentages.length; i++) {
        final name = muscles[i].toString();
        final percent = (percentages[i] as num?)?.toDouble() ?? 0;
        muscleMap[name] = (muscleMap[name] ?? 0) + percent;
      }
    }

    final total = muscleMap.values.isEmpty
        ? 1.0
        : muscleMap.values.reduce((a, b) => a + b);
    final sorted = muscleMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final muscleText = sorted
        .take(4)
        .map((e) => "${e.key} ${((e.value / total) * 100).toStringAsFixed(0)}%")
        .join(', ');

    return InkWell(
      onTap: _navigateToWorkoutMain, // FULL CARD TAP
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 0, vertical: 8), //horiz size change otto
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isTomorrow ? "Tomorrow's Workout" : "Your Next Workout",
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),

            // IMAGES — NOW TAPPABLE
            GestureDetector(
              onTap: _navigateToWorkoutMain,
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _exercises.length,
                  itemBuilder: (ctx, i) {
                    final ex = _exercises[i];
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
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
            ),
            const SizedBox(height: 16),

            if (muscleText.isNotEmpty)
              Text(muscleText,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            Text(
                "${_workout!['duration']} min • ${_exercises.length} exercises",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 12),

            Row(
              children: [
                CircleAvatar(
                    radius: 12,
                    backgroundImage:
                        NetworkImage(_workout!['coachPhoto'] ?? '')),
                const SizedBox(width: 8),
                Text(_workout!['coach'] ?? 'No Coach',
                    style: const TextStyle(color: Colors.orange)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                  onPressed: _navigateToWorkoutMain,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // BUTTONS FRAME
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 10), // Tighter
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navBtn(
                      Icons.refresh, "Regenerate", () => _regenerateToday()),
                  _navBtn(Icons.skip_next, _isTomorrow ? "Previous" : "Next",
                      () => _toggleDay()),
                  _navBtn(Icons.edit_note, "Edit", _navigateToWorkoutMain),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Transform.rotate(
          angle: _isTomorrow && icon == Icons.skip_next ? 3.14 : 0,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(50, 44),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              children: [
                Icon(Icons.fitness_center, size: 80, color: Colors.orange),
                SizedBox(height: 24),
                Text("No workout yet!",
                    style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                SizedBox(height: 16),
                Text("Tap below to get your first FREE Auto Coach workout!",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _generateFreeWorkout(),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 28),
              label: Text(_isLoading ? "Generating..." : "Get FREE Workout!",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REGENERATE TODAY
  Future<void> _regenerateToday() async {
    if (_workout == null) return;
    final docId = _workout!['id'];
    final newIds = await _getRandomExerciseIds();
    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(docId)
        .update({'exerciseIds': newIds});
    await _loadWorkout();
  }

  // TOGGLE + AUTO-GENERATE TOMORROW
  Future<void> _toggleDay() async {
    setState(() => _isTomorrow = !_isTomorrow);
    final exists = await _checkWorkoutExists();
    if (!exists) await _generateTomorrowWorkout();
    await _loadWorkout();
  }

  Future<bool> _checkWorkoutExists() async {
    final date = _isTomorrow
        ? DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')[0]
        : DateTime.now().toIso8601String().split('T')[0];
    final snap = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _generateTomorrowWorkout() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final date = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];
    final ids = await _getRandomExerciseIds();
    await FirebaseFirestore.instance.collection('workouts').add({
      'uid': uid,
      'date': date,
      'duration': 59,
      'coach': 'Auto Coach',
      'imageUrl': 'https://i.imgur.com/5K8zK5P.png',
      'exerciseIds': ids,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _getRandomExerciseIds() async {
    final snap = await FirebaseFirestore.instance
        .collection('exercises')
        .where('isAvailable', isEqualTo: true)
        .get();
    final docs = snap.docs..shuffle();
    return docs.take(5).map((d) => d.id).toList();
  }

  Future<void> _generateFreeWorkout() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      final userDoc = await userRef.get();
      int used = 0;
      if (!userDoc.exists) {
        await userRef.set({'freeWorkoutsUsed': 0}, SetOptions(merge: true));
      } else {
        used = (userDoc.data()?['freeWorkoutsUsed'] ?? 0) as int;
      }

      if (used >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No more free workouts!")));
        Navigator.pushNamed(context, '/subscriptions');
        return;
      }

      final ids = await _getRandomExerciseIds();
      await FirebaseFirestore.instance.collection('workouts').add({
        'uid': uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'duration': 59,
        'coach': 'Auto Coach',
        'coachPhoto': 'https://i.imgur.com/5K8zK5P.png',
        'exerciseIds': ids,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userRef.update({'freeWorkoutsUsed': used + 1});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Workout Generated!"), backgroundColor: Colors.green));
      await _loadWorkout();
    } catch (e) {
      print("ERROR: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkout() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final queryDate = _isTomorrow
        ? DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')[0]
        : today;

    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: queryDate)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _workout = null);
      return;
    }

    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    data['id'] = snapshot.docs.first.id; // SAVE ID FOR REGENERATE
    final ids = (data['exerciseIds'] as List).cast<String>();

    setState(() {
      _workout = data;
      _exercises = [];
    });

    final exDocs = await Future.wait(ids.map((id) =>
        FirebaseFirestore.instance.collection('exercises').doc(id).get()));
    final exercises = exDocs
        .where((d) => d.exists)
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();

    if (mounted) setState(() => _exercises = exercises);
  }
}
