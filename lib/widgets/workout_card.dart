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
  bool _isLoading = false;

  Map<String, dynamic>? _workout;
  List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
  }

  void _navigateToWorkoutMain(
      Map<String, dynamic> workout, List<Map<String, dynamic>> exercises) {
    Navigator.pushNamed(context, '/workout_main', arguments: {
      'workout': workout,
      'exercises': exercises,
    }).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final queryDate = _isTomorrow
        ? DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')[0]
        : DateTime.now().toIso8601String().split('T')[0];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: queryDate)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmptyCard();
        }

        final doc = snap.data!.docs.first;
        final workoutData = doc.data() as Map<String, dynamic>;
        workoutData['id'] = doc.id;

        // SAFE PARSING: exerciseIds
        List<String> ids = [];
        final rawIds = workoutData['exerciseIds'];
        if (rawIds is List) {
          ids = rawIds.whereType<String>().toList();
        } else if (rawIds is String && rawIds.trim().isNotEmpty) {
          ids = rawIds
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }

        if (ids.isEmpty) {
          return _buildEmptyCard();
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadExercises(ids),
          builder: (context, exSnap) {
            if (exSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.orange));
            }

            final exercises = exSnap.data ?? [];

            // MUSCLE DISTRIBUTION — FULLY SAFE
            final muscleMap = <String, double>{};
            for (var ex in exercises) {
              // SAFE: muscles
              List<String> muscles = [];
              final rawMuscles = ex['muscles'];
              if (rawMuscles is List) {
                muscles = rawMuscles.whereType<String>().toList();
              } else if (rawMuscles is String && rawMuscles.trim().isNotEmpty) {
                muscles = rawMuscles
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              }

              // SAFE: muscleDistribution
              List<double> percentages = [];
              final rawPerc = ex['muscleDistribution'];
              if (rawPerc is List) {
                percentages =
                    rawPerc.whereType<num>().map((n) => n.toDouble()).toList();
              } else if (rawPerc is String && rawPerc.trim().isNotEmpty) {
                percentages = rawPerc
                    .split(',')
                    .map((s) => double.tryParse(s.trim()) ?? 0.0)
                    .toList();
              }

              for (int i = 0;
                  i < muscles.length && i < percentages.length;
                  i++) {
                final name = muscles[i];
                final percent = percentages[i];
                muscleMap[name] = (muscleMap[name] ?? 0) + percent;
              }
            }

            final total = muscleMap.values.fold(0.0, (a, b) => a + b) > 0
                ? muscleMap.values.fold(0.0, (a, b) => a + b)
                : 1.0;
            final sorted = muscleMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final muscleText = sorted
                .take(4)
                .map((e) =>
                    "${e.key} ${((e.value / total) * 100).toStringAsFixed(0)}%")
                .join(', ');

            return InkWell(
              onTap: () => _navigateToWorkoutMain(workoutData, exercises),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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

                    // Images
                    GestureDetector(
                      onTap: () =>
                          _navigateToWorkoutMain(workoutData, exercises),
                      child: SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: exercises.length,
                          itemBuilder: (ctx, i) {
                            final ex = exercises[i];
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
                        "${workoutData['duration']} min • ${exercises.length} exercises",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        CircleAvatar(
                            radius: 12,
                            backgroundImage:
                                NetworkImage(workoutData['coachPhoto'] ?? '')),
                        const SizedBox(width: 8),
                        Text(workoutData['coach'] ?? 'No Coach',
                            style: const TextStyle(color: Colors.orange)),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Buttons with separators
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _navBtn(Icons.refresh, "Regenerate",
                              () => _regenerateToday(workoutData['id'])),
                          const VerticalDivider(
                            color: Colors.grey,
                            thickness: 1,
                            indent: 10,
                            endIndent: 10,
                          ),
                          _navBtn(
                              Icons.skip_next,
                              _isTomorrow ? "Previous" : "Next",
                              () => _toggleDay()),
                          const VerticalDivider(
                            color: Colors.grey,
                            thickness: 1,
                            indent: 10,
                            endIndent: 10,
                          ),
                          _navBtn(
                              Icons.edit_note,
                              "Edit",
                              () => _navigateToWorkoutMain(
                                  workoutData, exercises)),
                          const VerticalDivider(
                            color: Colors.grey,
                            thickness: 1,
                            indent: 10,
                            endIndent: 10,
                          ),
                          _navBtn(
                              Icons.add, "New", () => _createBlankWorkout()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadExercises(List<String> ids) async {
    if (ids.isEmpty) return [];

    final exDocs = await Future.wait(
      ids.map((id) =>
          FirebaseFirestore.instance.collection('exercises').doc(id).get()),
    );

    final missingIds = <String>[];
    final exercises = <Map<String, dynamic>>[];
    for (int i = 0; i < exDocs.length; i++) {
      if (exDocs[i].exists) {
        exercises.add(exDocs[i].data()!);
      } else {
        missingIds.add(ids[i]);
      }
    }

    if (missingIds.isNotEmpty) {
      final customDocs = await Future.wait(
        missingIds.map((id) => FirebaseFirestore.instance
            .collection('exercises_custom')
            .doc(id)
            .get()),
      );
      exercises.addAll(customDocs.where((d) => d.exists).map((d) => d.data()!));
    }

    return exercises;
  }

  Widget _navBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: _isTomorrow && icon == Icons.skip_next ? 3.14 : 0,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            minimumSize: const Size(50, 44)),
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
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _generateFreeWorkout(),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 28),
                  label: Text(
                      _isLoading ? "Generating..." : "Get FREE Workout!",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _createBlankWorkout(),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add, size: 28),
                  label: Text(
                    _isLoading ? "Creating..." : "Create Blank Workout",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor:
                        Colors.white, // This forces icon + text to white
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateToday(String workoutId) async {
    final newIds = await _getRandomExerciseIds();
    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(workoutId)
        .update({'exerciseIds': newIds});
  }

  Future<void> _toggleDay() async {
    setState(() => _isTomorrow = !_isTomorrow);
    final exists = await _checkWorkoutExists();
    if (!exists) await _generateTomorrowWorkout();
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
    } catch (e) {
      print("ERROR: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // === NEW: CLEANUP INCOMPLETE WORKOUTS (FIXED) ===
  Future<void> _cleanupIncompleteWorkouts() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();
    int deletedCount = 0;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: uid)
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['completedAt'] == null) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint("Cleaned up $deletedCount incomplete workouts.");
      }
    } catch (e) {
      debugPrint("Cleanup failed: $e");
    }
  }

  Future<void> _createBlankWorkout() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // STEP 1: Clean up old incomplete workouts
      await _cleanupIncompleteWorkouts();

      // STEP 2: Create new blank workout
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final date = DateTime.now().toIso8601String().split('T')[0];
      final docRef =
          await FirebaseFirestore.instance.collection('workouts').add({
        'uid': uid,
        'date': date,
        'duration': 0,
        'coach': 'No Coach',
        'coachPhoto': '',
        'exerciseIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final workout = {
        'id': docRef.id,
        'date': date,
        'duration': 0,
        'coach': 'No Coach',
        'coachPhoto': '',
        'exerciseIds': [],
      };

      _navigateToWorkoutMain(workout, []);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Blank Workout Created!"),
          backgroundColor: Colors.green));
    } catch (e) {
      print("ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create blank workout")));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
