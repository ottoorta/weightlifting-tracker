// lib/screens/workout_main.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_exercise.dart';

class WorkoutMainScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final List<Map<String, dynamic>> exercises;

  const WorkoutMainScreen({
    super.key,
    required this.workout,
    required this.exercises,
  });

  @override
  State<WorkoutMainScreen> createState() => _WorkoutMainScreenState();
}

class _WorkoutMainScreenState extends State<WorkoutMainScreen> {
  bool isWorkoutStarted = false;
  bool isWorkoutComplete = false;
  Duration elapsedDuration = Duration.zero;
  int calories = 0;
  double volume = 0.0;
  late Timer _timer;
  final DateFormat dateFormat = DateFormat('EEEE, MMMM d');

  @override
  void initState() {
    super.initState();
    _checkWorkoutStatus();
  }

  Future<void> _checkWorkoutStatus() async {
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();

    if (!workoutDoc.exists) return;

    final data = workoutDoc.data()!;
    final startTime = data['startTime'] as Timestamp?;
    final endTime = data['endTime'] as Timestamp?;

    if (startTime != null) {
      setState(() {
        isWorkoutStarted = true;
        elapsedDuration = DateTime.now().difference(startTime.toDate());
      });
      _startTimer();
    }

    if (endTime != null) {
      setState(() {
        isWorkoutComplete = true;
      });
      if (_timer.isActive) _timer.cancel();
    } else if (isWorkoutStarted) {
      await _calculateTotals();
      final allComplete = await _areAllExercisesComplete();
      if (allComplete && mounted) {
        await _finishWorkout();
      }
    }
  }

  Future<bool> _areAllExercisesComplete() async {
    for (var ex in widget.exercises) {
      final exerciseId = await _getExerciseId(ex);
      final loggedCount = await _getLoggedSetsCount(exerciseId);
      final totalSets = ex['sets'] ?? 4;
      if (loggedCount < totalSets) return false;
    }
    return true;
  }

  Future<String> _getExerciseId(Map<String, dynamic> ex) async {
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();

    if (!workoutDoc.exists) return 'unknown';

    final data = workoutDoc.data()!;
    final List<dynamic> exerciseIds = data['exerciseIds'] ?? [];

    final exerciseName = ex['name']?.toString().toLowerCase() ?? '';
    for (String id in exerciseIds) {
      final exDoc = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .get();
      if (exDoc.exists &&
          exDoc['name']?.toString().toLowerCase() == exerciseName) {
        return id;
      }
    }
    return 'unknown';
  }

  Future<int> _getLoggedSetsCount(String exerciseId) async {
    if (exerciseId == 'unknown') return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .collection('logged_sets')
        .where('exerciseId', isEqualTo: exerciseId)
        .get();
    return snapshot.docs.length;
  }

  Future<void> _calculateTotals() async {
    if (!mounted) return;

    int totalCal = 0;
    double totalVol = 0.0;

    for (var ex in widget.exercises) {
      final exerciseId = await _getExerciseId(ex);
      if (exerciseId == 'unknown') continue;

      final snapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workout['id'])
          .collection('logged_sets')
          .where('exerciseId', isEqualTo: exerciseId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final reps = data['reps'] as double? ?? 0;
        final weight = data['weight'] as double? ?? 0;
        totalVol += reps * weight;
        totalCal += (reps * weight * 0.05).toInt();
      }
    }

    if (mounted) {
      setState(() {
        calories = totalCal;
        volume = totalVol;
      });
    }
  }

  void _startWorkout() async {
    setState(() => isWorkoutStarted = true);

    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .set({'startTime': FieldValue.serverTimestamp()},
            SetOptions(merge: true));

    _startTimer();
    await _calculateTotals();
  }

  Future<void> _finishWorkout() async {
    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .set(
            {'endTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    if (mounted) {
      setState(() => isWorkoutComplete = true);
      if (_timer.isActive) _timer.cancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        elapsedDuration = elapsedDuration + const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours}:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.workout['date'] != null
        ? dateFormat.format(DateTime.parse(widget.workout['date']))
        : 'Today';

    String buttonText;
    Color buttonColor = Colors.orange;
    VoidCallback? onPressed;

    if (isWorkoutComplete) {
      buttonText = "WORKOUT COMPLETED";
      buttonColor = Colors.green;
      onPressed = null;
    } else if (isWorkoutStarted) {
      buttonText = "WORKOUT IN PROGRESS";
      onPressed = _finishWorkout;
    } else {
      buttonText = "START WORKOUT";
      onPressed = _startWorkout;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(dateStr,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: const [Icon(Icons.share, color: Colors.orange)],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(children: [
                        CircleAvatar(
                            radius: 16, backgroundColor: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text("Personal Coach: Otto Orta",
                            style: TextStyle(color: Colors.orange))
                      ]),
                      SizedBox(height: 8),
                      Text(
                          "Today’s Workout Details: We will focus on maximizing effort on Triceps, Quads and Calves since they are showing weakness...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Target Muscles",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      MuscleTargetChip(
                          name: "Chest", percent: 100, color: Colors.red),
                      MuscleTargetChip(
                          name: "Triceps", percent: 75, color: Colors.blue),
                      MuscleTargetChip(
                          name: "Quads", percent: 65, color: Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox(
                        "Duration",
                        isWorkoutStarted
                            ? _formatDuration(elapsedDuration)
                            : "30 mins"),
                    _statBox("Calories", "$calories kcal"),
                    _statBox("Volume", "${volume.toStringAsFixed(0)} Kg"),
                  ],
                ),
                const SizedBox(height: 20),
                ...widget.exercises.map((ex) => _exerciseCard(ex)).toList(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          Positioned(
            bottom: 52,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                disabledBackgroundColor: buttonColor.withOpacity(0.5),
                minimumSize: const Size(double.infinity, 56),
                shape: const StadiumBorder(),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ],
      );

  Widget _exerciseCard(Map<String, dynamic> ex) {
    return FutureBuilder<String>(
      future: _getExerciseId(ex),
      builder: (context, idSnapshot) {
        if (!idSnapshot.hasData || idSnapshot.data == 'unknown') {
          return const SizedBox.shrink();
        }
        final exerciseId = idSnapshot.data!;
        return FutureBuilder<int>(
          future: _getLoggedSetsCount(exerciseId),
          builder: (context, countSnapshot) {
            final loggedCount = countSnapshot.data ?? 0;
            final totalSets = ex['sets'] ?? 4;
            final isComplete = loggedCount >= totalSets;

            return GestureDetector(
              onTap: () async {
                if (!isWorkoutStarted) _startWorkout();

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutExerciseScreen(
                      exercise: {
                        ...ex,
                        'id': exerciseId, // PASS THE REAL ID
                      },
                      workoutId: widget.workout['id'],
                      isViewOnly: isWorkoutComplete,
                    ),
                  ),
                );

                if (!mounted) return;

                await _checkWorkoutStatus();
                await _calculateTotals();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.orange : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        ex['imageUrl']?.toString().isNotEmpty == true
                            ? ex['imageUrl']
                            : 'https://via.placeholder.com/90',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey[800],
                          child: const Icon(Icons.fitness_center,
                              color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex['name'] ?? 'Exercise',
                            style: TextStyle(
                                color: isComplete ? Colors.white : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${ex['sets'] ?? 4} sets • ${ex['reps'] ?? '10-12'} reps • ${ex['weight'] ?? '20'} kg",
                            style: TextStyle(
                                color: isComplete
                                    ? Colors.white70
                                    : Colors.white60,
                                fontSize: 14),
                          ),
                          if (isComplete)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "$totalSets sets completed",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          if (!isComplete && loggedCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "$loggedCount/$totalSets sets logged",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.more_vert, color: Colors.orange),
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
}

class MuscleTargetChip extends StatelessWidget {
  final String name;
  final int percent;
  final Color color;
  const MuscleTargetChip(
      {super.key,
      required this.name,
      required this.percent,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<String>(
            future: _getMuscleImageUrl(name),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(snapshot.data!,
                      width: 40, height: 40, fit: BoxFit.cover),
                );
              }
              return Container(width: 40, height: 40, color: Colors.grey[800]);
            },
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              Text("$percent%",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Future<String> _getMuscleImageUrl(String muscleName) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('muscles')
          .where('name', isEqualTo: muscleName)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return '';
      final url = snap.docs.first['imageUrl'] as String?;
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('gs://')) {
        final path = url.replaceFirst(
            'gs://weightlifting-tracker-a9834.firebasestorage.app/', '');
        return 'https://firebasestorage.googleapis.com/v0/b/weightlifting-tracker-a9834.appspot.com/o/$path?alt=media';
      }
      return url;
    } catch (e) {
      return '';
    }
  }
}
