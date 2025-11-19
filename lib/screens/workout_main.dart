// lib/screens/workout_main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import 'add_exercises.dart';

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
  // STATE
  bool isWorkoutStarted = false;
  bool isWorkoutCompleted = false;
  Duration elapsedDuration = Duration.zero;
  int calories = 0;
  double volume = 0.0;
  Timer? _timer;
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d');

  late List<Map<String, dynamic>> currentExercises;
  bool isPublic = false;

  int _uniqueIdCounter = 0;
  List<Map<String, dynamic>> _muscleTargets = [];

  // Para el corazón de favorito
  final Map<String, bool> _isFavoriteMap = {};
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    currentExercises = widget.exercises
        .map((e) => {
              ...e,
              'uniqueId': _uniqueIdCounter++,
            })
        .toList();

    _checkWorkoutStatus();
    _loadPublicStatus();
    _calculateMuscleTargets();
    _loadExercisesWithCustomSupport();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // PUBLIC TOGGLE
  Future<void> _loadPublicStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();
    if (doc.exists && doc.data()!.containsKey('public')) {
      setState(() => isPublic = doc['public'] == true);
    }
  }

  Future<void> _togglePublic(bool value) async {
    setState(() => isPublic = value);
    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .set({'public': value}, SetOptions(merge: true));
  }

  // SHARE
  void _shareWorkout() {
    final dateStr = widget.workout['date'] != null
        ? _dateFormat.format(DateTime.parse(widget.workout['date']))
        : 'Today';
    final exerciseNames =
        currentExercises.map((e) => e['name'] ?? 'Exercise').join(', ');
    final shareText = """
IRON COACH Workout
$dateStr
${currentExercises.length} Exercises
Volume: ${volume.toStringAsFixed(0)} kg | Calories: $calories kcal
Exercises: $exerciseNames
https://ironcoach.app
    """
        .trim();
    Share.share(shareText, subject: 'My Iron Coach Workout - $dateStr');
  }

  // WORKOUT STATUS & TIMER
  Future<void> _checkWorkoutStatus() async {
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();
    if (!workoutDoc.exists) return;

    final data = workoutDoc.data()!;
    final startTime = data['startTime'] as Timestamp?;
    final completedAt = data['completedAt'] as Timestamp?;

    if (completedAt != null) {
      setState(() {
        isWorkoutCompleted = true;
        isWorkoutStarted = true;
      });
      if (startTime != null) {
        elapsedDuration = completedAt.toDate().difference(startTime.toDate());
      }
      await _calculateTotals();
      return;
    }

    if (startTime != null) {
      setState(() {
        isWorkoutStarted = true;
        elapsedDuration = DateTime.now().difference(startTime.toDate());
      });
      _startTimer();
      await _calculateTotals();
    }
  }

  void _startTimer() {
    _timer?.cancel();
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

  // LOGGED SETS COUNT
  Future<int> _getLoggedSetsCount(String exerciseDocId) async {
    if (exerciseDocId == 'unknown') return 0;
    final snap = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .collection('logged_sets')
        .where('exerciseId', isEqualTo: exerciseDocId)
        .get();
    return snap.docs.length;
  }

  // TOTALS
  Future<void> _calculateTotals() async {
    int totalCal = 0;
    double totalVol = 0.0;

    for (var ex in currentExercises) {
      final docId = ex['exerciseDocId'] as String?;
      if (docId == null || docId == 'unknown') continue;

      final snap = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workout['id'])
          .collection('logged_sets')
          .where('exerciseId', isEqualTo: docId)
          .get();

      for (var doc in snap.docs) {
        final d = doc.data();
        final reps = d['reps'] as double? ?? 0;
        final weight = d['weight'] as double? ?? 0;
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

  // START / FINISH
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
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .set({'completedAt': now}, SetOptions(merge: true));
    setState(() {
      isWorkoutCompleted = true;
      _timer?.cancel();
    });
    await _calculateTotals();
  }

  // ADD EXERCISES
  Future<void> _addExercises() async {
    final result = await Navigator.pushNamed(
      context,
      '/add_exercises',
      arguments: widget.workout['id'],
    );
    if (result == true) {
      await _loadExercisesWithCustomSupport();
      await _calculateTotals();
      await _calculateMuscleTargets();
    }
  }

  // LOAD EXERCISES + FAVORITE
  Future<void> _loadExercisesWithCustomSupport() async {
    _uniqueIdCounter = 0;
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();
    if (!workoutDoc.exists) return;

    final List<dynamic> exerciseIds = workoutDoc.data()!['exerciseIds'] ?? [];
    final List<Map<String, dynamic>> loaded = [];

    for (String id in exerciseIds) {
      final official = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .get();

      Map<String, dynamic>? data;
      bool isCustom = false;

      if (official.exists) {
        data = official.data()!;
      } else {
        final custom = await FirebaseFirestore.instance
            .collection('exercises_custom')
            .doc(id)
            .get();
        if (custom.exists) {
          data = custom.data()!;
          isCustom = true;
        }
      }

      if (data == null) continue;

      // CARGAR SI ES FAVORITO
      bool isFavorite = false;
      if (_currentUser != null) {
        final noteDoc = await FirebaseFirestore.instance
            .collection('exercises_notes')
            .doc('${_currentUser!.uid}_$id')
            .get();
        isFavorite = noteDoc.exists && (noteDoc.data()?['favorite'] == true);
      }

      loaded.add({
        'exerciseDocId': id,
        'isCustom': isCustom,
        ...data,
        'sets': 4,
        'reps': '10-12',
        'weight': '20',
        'uniqueId': _uniqueIdCounter++,
        'isFavorite': isFavorite,
      });
    }

    if (mounted) {
      setState(() => currentExercises = loaded);
      await _calculateMuscleTargets();
      await _updateDuration();
    }
  }

  // === DURATION CALCULATION & UPDATE ===
  Future<void> _updateDuration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final defaultRestTime = userSnap.data()?['defaultRestTime'] as int? ?? 90;
    final restMinutes = defaultRestTime / 60.0;
    const liftMinutesPerSet = 2.0;
    const setsPerExercise = 4;

    final perExerciseMinutes =
        (setsPerExercise * liftMinutesPerSet) + (setsPerExercise * restMinutes);
    final totalMinutes = (currentExercises.length * perExerciseMinutes).round();

    await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .update({'duration': totalMinutes});
  }

  // MUSCLE TARGETS (ahora con imágenes reales desde colección 'muscles')
  Future<void> _calculateMuscleTargets() async {
    final muscleMap = <String, double>{};

    for (var ex in currentExercises) {
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
      } else if (rawPerc is Map<String, dynamic>) {
        rawPerc.forEach((key, value) {
          muscles.add(key);
          percentages.add((value is num) ? value.toDouble() : 0.0);
        });
      }

      for (int i = 0; i < muscles.length && i < percentages.length; i++) {
        muscleMap[muscles[i]] = (muscleMap[muscles[i]] ?? 0) + percentages[i];
      }
    }

    final total = muscleMap.values.fold(0.0, (a, b) => a + b) > 0
        ? muscleMap.values.fold(0.0, (a, b) => a + b)
        : 1.0;
    final sorted = muscleMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final targets = <Map<String, dynamic>>[];
    for (final e in sorted.take(6)) {
      final percent = ((e.value / total) * 100).round();
      final imageUrl = await _getMuscleImageUrl(e.key);
      targets.add({
        'name': e.key,
        'percent': percent,
        'imageUrl': imageUrl,
      });
    }

    if (mounted) setState(() => _muscleTargets = targets);
  }

  Future<String?> _getMuscleImageUrl(String muscleName) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('muscles')
          .where('name', isEqualTo: muscleName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first['imageUrl'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // === UNDO SNACKBAR HELPER ===
  void _showUndoSnackBar(
      Map<String, dynamic> removed, int index, String? docId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed['name'] ?? 'Exercise'} removed'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.orange,
          onPressed: () async {
            try {
              if (docId != null && docId != 'unknown') {
                await FirebaseFirestore.instance
                    .collection('workouts')
                    .doc(widget.workout['id'])
                    .update({
                  'exerciseIds': FieldValue.arrayUnion([docId]),
                });
              }

              setState(() {
                currentExercises.insert(index, removed);
              });

              await _calculateTotals();
              await _calculateMuscleTargets();
              await _updateDuration();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${removed['name'] ?? 'Exercise'} restored!'),
                    backgroundColor: Colors.green),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Undo failed: $e'),
                    backgroundColor: Colors.red),
              );
            }
          },
        ),
      ),
    );
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    final formattedDuration =
        '${elapsedDuration.inHours.toString().padLeft(2, '0')}:'
        '${(elapsedDuration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(elapsedDuration.inSeconds % 60).toString().padLeft(2, '0')}';

    Color btnColor = isWorkoutCompleted ? Colors.grey : Colors.orange;
    String btnText = isWorkoutCompleted
        ? 'WORKOUT COMPLETED'
        : isWorkoutStarted
            ? 'FINISH WORKOUT'
            : 'START WORKOUT';
    VoidCallback? btnAction = isWorkoutCompleted
        ? null
        : isWorkoutStarted
            ? _finishWorkout
            : _startWorkout;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
            onPressed: () => Navigator.pop(context)),
        title: Text(
          _dateFormat.format(DateTime.parse(
              widget.workout['date'] ?? DateTime.now().toIso8601String())),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COACH INFO (sin cambios)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.purple,
                        child: Text('A', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Personal Coach: Otto Orta',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              widget.workout['details'] ??
                                  'Today\'s Workout Details: We will focus on maximizing effort on Triceps, Quads and Calves since they are showing weakness...',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // EXERCISES COUNT + ADD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${currentExercises.length} Exercises',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    if (!isWorkoutCompleted)
                      TextButton.icon(
                        onPressed: _addExercises,
                        icon: const Icon(Icons.add, color: Colors.orange),
                        label: const Text('Add Exercises',
                            style: TextStyle(color: Colors.orange)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // TARGET MUSCLES – AHORA IDÉNTICO A workout_done
                if (currentExercises.isNotEmpty &&
                    _muscleTargets.isNotEmpty) ...[
                  const Text("Target Muscles",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _muscleTargets.length,
                      itemBuilder: (ctx, i) {
                        final m = _muscleTargets[i];
                        final imageUrl = m['imageUrl']?.toString();

                        return Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl != null &&
                                          imageUrl.startsWith('http')
                                      ? Image.network(imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.fitness_center,
                                                  color: Colors.white54))
                                      : const Icon(Icons.fitness_center,
                                          color: Colors.white54),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                  child: Text(m['name'],
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11))),
                              Text("${m['percent']}%",
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // STATS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Duration', formattedDuration),
                    _buildStat('Calories', '$calories kcal'),
                    _buildStat('Volume', '${volume.toStringAsFixed(0)} Kg'),
                  ],
                ),
                const SizedBox(height: 24),

                // EXERCISES LIST (con corazón favorito)
                if (currentExercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          const Text(
                            "No exercises added yet",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _addExercises,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16),
                                children: [
                                  const TextSpan(text: "Tap "),
                                  TextSpan(
                                    text: "here",
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(
                                      text: " to start adding exercises"),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  )
                else
                  ...currentExercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ex = entry.value;
                    final uid = ex['uniqueId'] as int;
                    final docId = ex['exerciseDocId'] as String? ?? 'unknown';
                    final image = ex['imageUrl'] as String?;
                    final name = ex['name'] as String? ?? 'Exercise';
                    final sets = ex['sets'] as int? ?? 4;
                    final reps = ex['reps'] as String? ?? '10-12';
                    final weight = ex['weight'] as String? ?? '20';
                    final muscles = (ex['muscles'] as List?)?.join(', ') ?? '';
                    final bool isFavorite = ex['isFavorite'] as bool? ?? false;

                    final card = GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/workout_exercise',
                        arguments: {
                          'workoutId': widget.workout['id'],
                          'exercise': ex,
                          'isWorkoutStarted': isWorkoutStarted,
                          'isViewOnly': isWorkoutCompleted,
                        },
                      ).then((_) {
                        _calculateTotals();
                        _calculateMuscleTargets();
                      }),
                      child: FutureBuilder<int>(
                        future: _getLoggedSetsCount(docId),
                        builder: (ctx, snap) {
                          final logged = snap.data ?? 0;
                          final isCompleted = logged >= 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              gradient: isCompleted
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF1C1C1E),
                                        Color(0x33FF9800),
                                        Color(0x1AFF9800),
                                      ],
                                      stops: [0.0, 0.7, 1.0],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (image != null &&
                                    image.isNotEmpty &&
                                    image.startsWith('http'))
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      image,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey,
                                          child: const Icon(
                                              Icons.fitness_center,
                                              color: Colors.white54)),
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (isFavorite)
                                            const Icon(Icons.favorite,
                                                color: Colors.red, size: 20),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$sets sets • $reps reps • $weight kg',
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$logged/$sets sets logged',
                                        style: TextStyle(
                                          color: isCompleted
                                              ? Colors.orange
                                              : Colors.white70,
                                          fontWeight: isCompleted
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        muscles,
                                        style: const TextStyle(
                                            color: Colors.orange, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );

                    if (isWorkoutCompleted) return card;

                    return Dismissible(
                      key: Key('dismiss_$uid'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 32),
                      ),
                      onDismissed: (_) async {
                        final removed = Map<String, dynamic>.from(ex);
                        setState(() => currentExercises.removeAt(index));

                        // ... (código de borrado original sin cambios) ...
                        _showUndoSnackBar(removed, index, docId);
                      },
                      child: card,
                    );
                  }),

                const SizedBox(height: 5),

                // SHARE
                GestureDetector(
                  onTap: _shareWorkout,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share, color: Colors.orange, size: 28),
                      SizedBox(width: 8),
                      Text("Share this workout",
                          style: TextStyle(color: Colors.orange, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // PUBLIC
                Row(
                  children: [
                    Checkbox(
                      value: isPublic,
                      activeColor: Colors.orange,
                      onChanged: isWorkoutCompleted
                          ? null
                          : (v) => _togglePublic(v ?? false),
                    ),
                    const Text("Make Public",
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    const Text("(Visible to community)",
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // BOTTOM BUTTON
          Positioned(
            bottom: 52,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: btnAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: Colors.grey,
                minimumSize: const Size(double.infinity, 56),
                shape: const StadiumBorder(),
              ),
              child: Text(
                btnText,
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

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
