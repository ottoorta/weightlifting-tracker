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

  // LOAD EXERCISES
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
      if (official.exists) {
        final data = official.data()!;
        loaded.add({
          'exerciseDocId': id,
          'isCustom': false,
          ...data,
          'sets': 4,
          'reps': '10-12',
          'weight': '20',
          'uniqueId': _uniqueIdCounter++,
        });
        continue;
      }

      final custom = await FirebaseFirestore.instance
          .collection('exercises_custom')
          .doc(id)
          .get();
      if (custom.exists) {
        final cData = custom.data()!;
        final isOwner =
            cData['userId'] == FirebaseAuth.instance.currentUser?.uid;
        final isPublic = cData['isPublic'] == true;
        if (isOwner || isPublic) {
          loaded.add({
            'exerciseDocId': id,
            'isCustom': true,
            ...cData,
            'sets': 4,
            'reps': '10-12',
            'weight': '20',
            'uniqueId': _uniqueIdCounter++,
          });
        }
      }
    }

    if (mounted) {
      setState(() => currentExercises = loaded);
      await _calculateMuscleTargets();
      await _updateDuration(); // <-- NEW: Update duration after load
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

    final defaultRestTime =
        userSnap.data()?['defaultRestTime'] as int? ?? 90; // seconds
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

  // MUSCLE TARGETS
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
    for (final e in sorted.take(4)) {
      final percent = ((e.value / total) * 100).round();
      final imageUrl = await _getMuscleImageUrl(e.key);
      targets.add({
        'name': e.key,
        'percent': percent,
        'color': _getMuscleColor(e.key),
        'imageUrl': imageUrl,
      });
    }

    if (mounted) setState(() => _muscleTargets = targets);
  }

  // MUSCLE IMAGE
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
      return null;
    } catch (e) {
      return null;
    }
  }

  // MUSCLE COLOR
  Color _getMuscleColor(String muscle) {
    final map = {
      'chest': Colors.red,
      'back': Colors.blue,
      'triceps': Colors.orange,
      'biceps': Colors.purple,
      'quads': Colors.green,
      'calves': Colors.yellow,
      'shoulders': Colors.pink,
    };
    return map[muscle.toLowerCase()] ?? Colors.green;
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
              await _updateDuration(); // <-- Recalculate duration on undo

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
                // COACH INFO
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

                // TARGET MUSCLES
                const Text('Target Muscles',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _muscleTargets.length,
                    itemBuilder: (ctx, idx) {
                      final t = _muscleTargets[idx];
                      final imageUrl = t['imageUrl']?.toString().trim();
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (imageUrl != null &&
                                      imageUrl.isNotEmpty &&
                                      imageUrl.startsWith('http'))
                                  ? Image.network(
                                      imageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                Text("${t['percent']}%",
                                    style: TextStyle(
                                        color: t['color'],
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

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

                // EXERCISES LIST
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
                            // Orange overlay only if completed
                            gradient: isCompleted
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF1C1C1E),
                                      Color(0x33FF9800), // Orange 20%
                                      Color(0x1AFF9800), // Orange 10%
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
                              // IMAGE
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
                                        child: const Icon(Icons.fitness_center,
                                            color: Colors.white54)),
                                  ),
                                ),
                              const SizedBox(width: 16),

                              // TEXT COLUMN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // NAME
                                    Text(
                                      name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),

                                    // SETS • REPS • WEIGHT
                                    Text(
                                      '$sets sets • $reps reps • $weight kg',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    const SizedBox(height: 4),

                                    // LOGGED SETS
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

                                    // MUSCLES
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
                      debugPrint('On Dismisseddddddddddddddddddd');
                      final removed = Map<String, dynamic>.from(ex);

                      // === 1. Optimistic UI Remove ===
                      setState(() => currentExercises.removeAt(index));

                      String? docId;
                      try {
                        // === 2. Fetch current exerciseIds ===
                        final workoutSnap = FirebaseFirestore.instance
                            .collection('workouts')
                            .doc(widget.workout['id'])
                            .get();

                        final snapshot = await workoutSnap;
                        final currentIds = List<String>.from(
                            snapshot.data()?['exerciseIds'] ?? []);

                        if (index < currentIds.length) {
                          docId = currentIds[index];
                          debugPrint('Fetched docId from index: $docId');
                        } else {
                          debugPrint('Index out of bounds for exerciseIds');
                        }
                      } catch (e) {
                        debugPrint('Failed to fetch exerciseIds: $e');
                      }

                      // === 3. Final check ===
                      if (docId == null || docId.isEmpty) {
                        debugPrint('No valid docId — skipping Firestore ops');
                        await _calculateTotals();
                        await _calculateMuscleTargets();
                        await _updateDuration(); // <-- Recalculate on remove
                        _showUndoSnackBar(removed, index, docId);
                        return;
                      }

                      try {
                        final workoutRef = FirebaseFirestore.instance
                            .collection('workouts')
                            .doc(widget.workout['id']);

                        // === 4. Remove from exerciseIds ===
                        await workoutRef.update({
                          'exerciseIds': FieldValue.arrayRemove([docId]),
                        });

                        // === 5. Delete logged sets ===
                        final loggedSetsSnap = await workoutRef
                            .collection('logged_sets')
                            .where('exerciseId', isEqualTo: docId)
                            .get();

                        if (loggedSetsSnap.docs.isNotEmpty) {
                          final batch = FirebaseFirestore.instance.batch();
                          for (var doc in loggedSetsSnap.docs) {
                            batch.delete(doc.reference);
                          }
                          await batch.commit();
                        }

                        // === 6. Success ===
                        await _calculateTotals();
                        await _calculateMuscleTargets();
                        await _updateDuration(); // <-- Recalculate duration
                        _showUndoSnackBar(removed, index, docId);
                      } catch (e, stackTrace) {
                        debugPrint('DELETE FAILED: $e\n$stackTrace');

                        // === 7. ROLLBACK UI ===
                        setState(() => currentExercises.insert(index, removed));
                        await _calculateTotals();
                        await _calculateMuscleTargets();
                        await _updateDuration(); // <-- Recalculate on rollback

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delete failed: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    },
                    child: card,
                  );
                }).toList(),

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
