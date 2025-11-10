// lib/screens/workout_main.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  Duration elapsedDuration = Duration.zero;
  int calories = 0;
  double volume = 0.0;
  bool isPublic = false;

  late Timer _timer;
  final DateFormat dateFormat = DateFormat('EEEE, MMMM d');

  @override
  void dispose() {
    if (isWorkoutStarted) _timer.cancel();
    super.dispose();
  }

  void _startWorkout() {
    setState(() {
      isWorkoutStarted = true;
      elapsedDuration = Duration.zero;
      calories = 0;
      volume = 0.0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
  Widget build(BuildContext context) {
    final dateStr = widget.workout['date'] != null
        ? dateFormat.format(DateTime.parse(widget.workout['date']))
        : 'Today';

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
          // MAIN SCROLLABLE CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 120), // bottom padding for FAB
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coach Note
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
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Target Muscles
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

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox(
                        "Duration",
                        isWorkoutStarted
                            ? _formatDuration(elapsedDuration)
                            : "30 mins"),
                    _statBox("Calories",
                        isWorkoutStarted ? "$calories kcal" : "450 kcal"),
                    _statBox(
                        "Volume",
                        isWorkoutStarted
                            ? "${volume.toStringAsFixed(0)} Kg"
                            : "2,358 Kg"),
                  ],
                ),
                const SizedBox(height: 20),

                // Exercises
                ...widget.exercises.map((ex) => _exerciseCard(ex)).toList(),

                const SizedBox(height: 24),

                // SHARE + MAKE PUBLIC — NOW IN SCROLL, LEFT-ALIGNED
                Row(children: const [
                  Icon(Icons.share, color: Colors.orange),
                  SizedBox(width: 8),
                  Text("Share workout", style: TextStyle(color: Colors.orange)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: isPublic,
                      activeColor: Colors.orange,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) => setState(() => isPublic = val!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("Make Public",
                      style: TextStyle(color: Colors.white)),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // FLOATING START BUTTON — ONLY THIS IS POSITIONED
          Positioned(
            bottom: 52,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: isWorkoutStarted ? null : _startWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                minimumSize: const Size(double.infinity, 56),
                shape: const StadiumBorder(),
              ),
              child: Text(
                isWorkoutStarted ? "WORKOUT IN PROGRESS" : "START WORKOUT",
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
    // DEBUG: See raw data
    print("Raw exercise data: $ex");

    // Extract lists
    final List<dynamic> muscleNames = ex['muscles'] ?? [];
    final List<dynamic> muscleValues = ex['muscleDistribution'] ?? [];

    // Build proper Map<String, int>
    final Map<String, int> musclesDist = {};
    for (int i = 0; i < muscleNames.length && i < muscleValues.length; i++) {
      final name = muscleNames[i].toString();
      final value = int.tryParse(muscleValues[i].toString()) ?? 0;
      if (value > 0) {
        musclesDist[name] = value;
      }
    }

    print(
        "Built musclesDist: $musclesDist"); // Should show: {Shoulders: 80, Trapezius: 20}

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DOMINANT IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              ex['imageUrl'] ?? '',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: Colors.grey,
                child: const Icon(Icons.fitness_center, color: Colors.white54),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  "${ex['sets'] ?? 4} sets • ${ex['reps'] ?? '10-12'} reps • ${ex['weight'] ?? '20'} kg",
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 10),

                // MUSCLE BADGES — NOW 100% WORKING
                if (musclesDist.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: musclesDist.entries.map((e) {
                      return Container(
                        child: Text(
                          "${e.key} ${e.value}%",
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  )
                else
                  const Text("No muscle data",
                      style: TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.more_vert, color: Colors.orange),
          ),
        ],
      ),
    );
  }
}

// MuscleTargetChip stays the same — already perfect
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
              return Container(width: 40, height: 40, color: Colors.grey);
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
