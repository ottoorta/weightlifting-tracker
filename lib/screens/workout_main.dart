// lib/screens/workout_main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import 'workout_exercise.dart';
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
  // -----------------------------------------------------------------
  //  STATE
  // -----------------------------------------------------------------
  bool isWorkoutStarted = false;
  bool isWorkoutCompleted = false;
  Duration elapsedDuration = Duration.zero;
  int calories = 0;
  double volume = 0.0;
  Timer? _timer;
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d');

  late List<Map<String, dynamic>> currentExercises;
  bool isPublic = false;

  /// Stable unique identifier for every list item.
  int _uniqueIdCounter = 0;

  // -----------------------------------------------------------------
  //  LIFECYCLE
  // -----------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    currentExercises = widget.exercises;
    _checkWorkoutStatus();
    _loadPublicStatus();
    _loadExercisesWithCustomSupport(); // ONE-TIME load
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------
  //  PUBLIC TOGGLE
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  //  SHARE
  // -----------------------------------------------------------------
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

Exercises:
$exerciseNames

Download Iron Coach and crush your goals!
https://ironcoach.app
    """
        .trim();

    Share.share(shareText, subject: 'My Iron Coach Workout - $dateStr');
  }

  // -----------------------------------------------------------------
  //  WORKOUT STATUS & TIMER
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  //  LOGGED-SETS COUNT – **cached per exercise**
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  //  TOTALS – uses cached IDs
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  //  START / FINISH
  // -----------------------------------------------------------------
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
        .set({'endTime': now, 'completedAt': now}, SetOptions(merge: true));

    // clean empty exercises
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workout['id'])
        .get();
    final data = workoutDoc.data()!;
    final List<dynamic> exerciseIds = List.from(data['exerciseIds'] ?? []);

    final List<String> toRemove = [];
    for (String id in exerciseIds) {
      if (await _getLoggedSetsCount(id) == 0) toRemove.add(id);
    }
    if (toRemove.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workout['id'])
          .update({'exerciseIds': FieldValue.arrayRemove(toRemove)});
    }

    setState(() => isWorkoutCompleted = true);
    _timer?.cancel();
  }

  // -----------------------------------------------------------------
  //  ADD EXERCISES
  // -----------------------------------------------------------------
  Future<void> _addExercises() async {
    final result = await Navigator.pushNamed(
      context,
      '/add_exercises',
      arguments: widget.workout['id'],
    );

    if (result == true) {
      await _loadExercisesWithCustomSupport();
      await _calculateTotals();
    }
  }

  // -----------------------------------------------------------------
  //  LOAD EXERCISES – **single source of truth**
  // -----------------------------------------------------------------
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
      // ---- OFFICIAL ----
      final official = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .get();

      if (official.exists) {
        loaded.add({
          'exerciseDocId': id, // <-- **real ID**
          'isCustom': false,
          ...official.data()!,
          'sets': 4,
          'reps': '10-12',
          'weight': '20',
          'uniqueId': _uniqueIdCounter++,
        });
        continue;
      }

      // ---- CUSTOM ----
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

    if (mounted) setState(() => currentExercises = loaded);
  }

  // -----------------------------------------------------------------
  //  UI HELPERS
  // -----------------------------------------------------------------
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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

  // -----------------------------------------------------------------
  //  SAFE IMAGE – handles file:// URLs
  // -----------------------------------------------------------------
  static const _ImagePlaceholder = SizedBox(
    width: 90,
    height: 90,
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
      ),
    ),
  );

  Widget _safeNetworkImage(dynamic rawUrl) {
    final String? url = rawUrl?.toString().trim();
    if (url == null ||
        url.isEmpty ||
        url == 'null' ||
        url.startsWith('file://')) {
      return Container(
        width: 90,
        height: 90,
        color: Colors.grey[800],
        child:
            const Icon(Icons.fitness_center, color: Colors.white54, size: 36),
      );
    }

    return Image.network(
      url,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, progress) =>
          progress == null ? child : _ImagePlaceholder,
      errorBuilder: (_, __, ___) => Container(
        width: 90,
        height: 90,
        color: Colors.grey[800],
        child:
            const Icon(Icons.fitness_center, color: Colors.white54, size: 36),
      ),
    );
  }

  // -----------------------------------------------------------------
  //  MUSCLES TEXT
  // -----------------------------------------------------------------
  Widget _buildMusclesText(Map<String, dynamic> ex) {
    final List<dynamic>? muscles = ex['muscles'] as List<dynamic>?;
    if (muscles == null || muscles.isEmpty) {
      return const Text(
        'Primary muscles',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      );
    }

    final muscleNames = muscles
        .map((m) => m.toString().trim())
        .where((m) => m.isNotEmpty)
        .take(3)
        .join(', ');

    return Text(
      muscleNames.isEmpty ? 'Primary muscles' : muscleNames,
      style: const TextStyle(color: Colors.white60, fontSize: 12),
      overflow: TextOverflow.ellipsis,
    );
  }

  // -----------------------------------------------------------------
  //  EXERCISE CARD – uses cached logged-count
  // -----------------------------------------------------------------
  Widget _buildExerciseCard(Map<String, dynamic> ex, int index) {
    final String docId = ex['exerciseDocId'] as String? ?? 'unknown';
    return FutureBuilder<int>(
      future: _getLoggedSetsCount(docId),
      builder: (context, countSnap) {
        if (!mounted) return const SizedBox.shrink();

        final logged = countSnap.data ?? 0;
        final totalSets = ex['sets'] ?? 4;
        final complete = logged >= totalSets;
        final hasProgress = logged > 0;

        final cardColor = isWorkoutCompleted
            ? Colors.grey[700]!
            : (hasProgress ? Colors.orange : const Color(0xFF1C1C1E));

        return GestureDetector(
          onTap: () async {
            if (!isWorkoutStarted) _startWorkout();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutExerciseScreen(
                  exercise: ex,
                  workoutId: widget.workout['id'],
                  isViewOnly: isWorkoutCompleted,
                ),
              ),
            );
            if (mounted) {
              await _checkWorkoutStatus();
              await _calculateTotals();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _safeNetworkImage(ex['imageUrl'])),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex['name'] ?? 'Exercise',
                        style: TextStyle(
                          color: hasProgress ? Colors.white : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${ex['sets'] ?? 4} sets • ${ex['reps'] ?? '10-12'} reps • ${ex['weight'] ?? '20'} kg",
                        style: TextStyle(
                          color: hasProgress ? Colors.white70 : Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMusclesText(ex),
                      if (complete)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "All sets completed",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      if (!complete && hasProgress)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "$logged/$totalSets sets logged",
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
  }

  // -----------------------------------------------------------------
  //  BUILD
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final dateStr = widget.workout['date'] != null
        ? _dateFormat.format(DateTime.parse(widget.workout['date']))
        : 'Today';

    String btnText;
    Color btnColor;
    VoidCallback? btnAction;
    if (isWorkoutCompleted || widget.workout['completedAt'] != null) {
      btnText = "WORKOUT COMPLETED";
      btnColor = Colors.grey;
      btnAction = null;
    } else if (isWorkoutStarted) {
      btnText = "FINISH WORKOUT";
      btnColor = Colors.green;
      btnAction = _finishWorkout;
    } else {
      btnText = "START WORKOUT";
      btnColor = Colors.orange;
      btnAction = _startWorkout;
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.share, color: Colors.orange),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coach Card (demo)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Exercises count + add
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${currentExercises.length} Exercises",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    if (!isWorkoutCompleted)
                      GestureDetector(
                        onTap: _addExercises,
                        child: const Row(
                          children: [
                            Text("Add Exercises",
                                style: TextStyle(color: Colors.orange)),
                            SizedBox(width: 4),
                            Icon(Icons.add, color: Colors.orange),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Target muscles (demo)
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

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox("Duration", _formatDuration(elapsedDuration)),
                    _statBox("Calories", "$calories kcal"),
                    _statBox("Volume", "${volume.toStringAsFixed(0)} Kg"),
                  ],
                ),
                const SizedBox(height: 20),

                // ==================== EXERCISE LIST ====================
                ...currentExercises.asMap().entries.map((e) {
                  final int index = e.key;
                  final Map<String, dynamic> ex = e.value;
                  final int uid = ex['uniqueId'] ??= _uniqueIdCounter++;

                  final Widget card = _buildExerciseCard(ex, index);

                  if (isWorkoutCompleted) return card;

                  return Dismissible(
                    key: Key('dismiss_$uid'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete,
                          color: Colors.white, size: 32),
                    ),
                    onDismissed: (_) async {
                      final scaffold = ScaffoldMessenger.of(context);
                      final removed = Map<String, dynamic>.from(ex);
                      final docId = removed['exerciseDocId'] as String?;

                      setState(() {
                        currentExercises.removeAt(index);
                      });

                      if (docId != null && docId != 'unknown') {
                        try {
                          await FirebaseFirestore.instance
                              .collection('workouts')
                              .doc(widget.workout['id'])
                              .update({
                            'exerciseIds': FieldValue.arrayRemove([docId])
                          });
                        } catch (_) {}
                      }

                      await _calculateTotals();

                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('${removed['name']} removed'),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () async {
                              if (docId != null && docId != 'unknown') {
                                await FirebaseFirestore.instance
                                    .collection('workouts')
                                    .doc(widget.workout['id'])
                                    .update({
                                  'exerciseIds': FieldValue.arrayUnion([docId])
                                });
                              }
                              setState(() {
                                currentExercises.insert(index, removed);
                              });
                              await _calculateTotals();
                            },
                          ),
                        ),
                      );
                    },
                    child: card,
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Share
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
                const SizedBox(height: 16),

                // Public checkbox
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

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Bottom button
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
}

// ---------------------------------------------------------------------
//  MUSCLE CHIP (demo)
// ---------------------------------------------------------------------
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
          Container(width: 40, height: 40, color: Colors.grey),
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
}
