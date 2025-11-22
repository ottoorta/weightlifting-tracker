// lib/screens/workout_done.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkoutDoneScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDoneScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDoneScreen> createState() => _WorkoutDoneScreenState();
}

class _WorkoutDoneScreenState extends State<WorkoutDoneScreen> {
  bool isLoading = true;
  Map<String, dynamic> workoutData = {};
  List<Map<String, dynamic>> exercises = [];
  List<Map<String, dynamic>> muscleTargets = [];

  double totalVolume = 0.0;
  int totalCalories = 0;
  int durationMinutes = 0;

  final DateFormat dateFormat = DateFormat('EEEE, MMMM do yyyy');
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Mapa para almacenar si cada ejercicio es favorito
  final Map<String, bool> _isFavoriteMap = {};

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }

  Future<void> _loadWorkoutDetails() async {
    try {
      final workoutDoc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .get();

      if (!workoutDoc.exists || currentUser == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final data = workoutDoc.data()!;
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      final startTime = (data['startTime'] as Timestamp?)?.toDate();

      durationMinutes = data['duration'] as int? ?? 0;
      if (completedAt != null && startTime != null) {
        durationMinutes = completedAt.difference(startTime).inMinutes;
      }

      final exerciseIds = List<String>.from(data['exerciseIds'] ?? []);
      final List<Map<String, dynamic>> loadedExercises = [];

      double volume = 0.0;
      int calories = 0;

      for (String id in exerciseIds) {
        DocumentSnapshot exerciseDoc = await FirebaseFirestore.instance
            .collection('exercises')
            .doc(id)
            .get();

        Map<String, dynamic>? exerciseData;
        bool isCustom = false;

        if (!exerciseDoc.exists) {
          exerciseDoc = await FirebaseFirestore.instance
              .collection('exercises_custom')
              .doc(id)
              .get();
          isCustom = true;
        }

        if (!exerciseDoc.exists) continue;

        exerciseData = exerciseDoc.data() as Map<String, dynamic>;
        final name = exerciseData['name'] ?? 'Unknown';
        final imageUrl = exerciseData['imageUrl']?.toString();
        final muscles = List<String>.from(exerciseData['muscles'] ?? []);
        final muscleDist = exerciseData['muscleDistribution'] is Map
            ? Map<String, dynamic>.from(exerciseData['muscleDistribution'])
            : <String, dynamic>{};

        // Cargar si es favorito
        final noteDoc = await FirebaseFirestore.instance
            .collection('exercises_notes')
            .doc('${currentUser!.uid}_$id')
            .get();

        final bool isFavorite =
            noteDoc.exists && (noteDoc.data()?['favorite'] == true);

        // Guardar en el mapa
        _isFavoriteMap[id] = isFavorite;

        // CARGAR LOGGED SETS
        final loggedSetsSnap = await FirebaseFirestore.instance
            .collection('workouts')
            .doc(widget.workoutId)
            .collection('logged_sets')
            .where('exerciseId', isEqualTo: id)
            .get();

        final List<QueryDocumentSnapshot> sortedDocs = loggedSetsSnap.docs
          ..sort((a, b) {
            final Map<String, dynamic>? dataA =
                a.data() as Map<String, dynamic>?;
            final Map<String, dynamic>? dataB =
                b.data() as Map<String, dynamic>?;
            final tsA = dataA?['timestamp'] as Timestamp?;
            final tsB = dataB?['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsA.compareTo(tsB);
          });

        final List<Map<String, dynamic>> sets = [];
        double maxWeight = 0.0;
        double best1RM = 0.0;
        int best1RMIndex = -1;
        int maxWeightIndex = -1;

        int index = 0;
        for (var doc in sortedDocs) {
          final Map<String, dynamic>? s = doc.data() as Map<String, dynamic>?;
          if (s == null) {
            index++;
            continue;
          }

          final double weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
          final int reps = (s['reps'] as num?)?.toInt() ?? 0;

          // Only skip if no valid reps; allow weight == 0 or null for bodyweight
          if (reps <= 0) {
            index++;
            continue;
          }

          // Include in volume/calories even for bodyweight (will be 0)
          volume += weight * reps;
          calories += (weight * reps * 0.05).toInt();

          if (weight > maxWeight) {
            maxWeight = weight;
            maxWeightIndex = index;
          }

          final estimated1RM = reps >= 37 ? weight : weight * 36 / (37 - reps);
          if (estimated1RM > best1RM) {
            best1RM = estimated1RM;
            best1RMIndex = index;
          }

          sets.add({
            'weight': weight,
            'reps': reps,
            'isBest1RM': false,
            'isMaxWeight': false,
          });

          index++;
        }

        if (best1RMIndex >= 0 && best1RMIndex < sets.length) {
          sets[best1RMIndex]['isBest1RM'] = true;
        }
        if (maxWeightIndex >= 0 && maxWeightIndex < sets.length) {
          sets[maxWeightIndex]['isMaxWeight'] = true;
        }

        loadedExercises.add({
          'exerciseId': id,
          'name': name,
          'imageUrl': imageUrl,
          'sets': sets,
          'maxWeight': maxWeight,
          'best1RM': best1RM,
          'muscles': muscles,
          'muscleDistribution': muscleDist,
          'isFavorite': isFavorite,
        });
      }

      // TARGET MUSCLES
      final muscleMap = <String, double>{};
      for (var ex in loadedExercises) {
        final muscles = ex['muscles'] as List<String>;
        final dist = ex['muscleDistribution'] as Map<String, dynamic>;
        for (var m in muscles) {
          final percent = dist[m]?.toDouble() ?? (100.0 / muscles.length);
          muscleMap[m] = (muscleMap[m] ?? 0) + percent;
        }
      }

      final total = muscleMap.values.fold(0.0, (a, b) => a + b);
      final sorted = muscleMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final targets = <Map<String, dynamic>>[];
      for (final e in sorted.take(6)) {
        final percent = total > 0 ? ((e.value / total) * 100).round() : 0;
        final imageUrl = await _getMuscleImage(e.key);
        targets.add({'name': e.key, 'percent': percent, 'imageUrl': imageUrl});
      }

      if (mounted) {
        setState(() {
          workoutData = data;
          exercises = loadedExercises;
          muscleTargets = targets;
          totalVolume = volume;
          totalCalories = calories;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading workout: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<String?> _getMuscleImage(String muscleName) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('muscles')
          .where('name', isEqualTo: muscleName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first['imageUrl'] as String?;
    } catch (_) {}
    return null;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return "$minutes mins";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "$h Hrs ${m > 0 ? '$m mins' : ''}";
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = workoutData['date'] != null
        ? dateFormat.format(DateTime.parse(workoutData['date']))
        : "Unknown Date";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(dateStr,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TARGET MUSCLES
                  if (muscleTargets.isNotEmpty) ...[
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
                        itemCount: muscleTargets.length,
                        itemBuilder: (ctx, i) {
                          final m = muscleTargets[i];
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
                                            color: Colors.white,
                                            fontSize: 11))),
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

                  Text("${exercises.length} Exercises",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat("Duration", _formatDuration(durationMinutes)),
                      _buildStat("Calories", "$totalCalories kcal"),
                      _buildStat(
                          "Volume", "${totalVolume.toStringAsFixed(0)} Kg"),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // EXERCISES
                  ...exercises.map((ex) {
                    final imageUrl = ex['imageUrl']?.toString();
                    final sets = ex['sets'] as List<Map<String, dynamic>>;
                    final bool isFavorite = ex['isFavorite'] as bool? ?? false;

                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/exercise_statistics',
                        arguments: {
                          'exerciseId': ex['exerciseId'],
                          'exerciseName': ex['name']
                        },
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imageUrl != null &&
                                      imageUrl.startsWith('http')
                                  ? Image.network(imageUrl,
                                      width: 90,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(
                                              Icons.fitness_center,
                                              color: Colors.white54)))
                                  : Container(
                                      width: 90,
                                      height: 120,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.fitness_center,
                                          color: Colors.white54)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ex['name'],
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
                                  const SizedBox(height: 8),

                                  // Sets
                                  ...sets.map((s) {
                                    final double weight = s['weight'] as double;
                                    final int reps = s['reps'] as int;
                                    final String weightText = weight > 0
                                        ? '${weight.toStringAsFixed(1)} Kg'
                                        : 'Bodyweight';
                                    final text = "$reps x $weightText";
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(
                                        children: [
                                          Text(text,
                                              style: const TextStyle(
                                                  color: Colors.white70)),
                                          if (s['isBest1RM'] == true) ...[
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 10),
                                                child: Icon(Icons.emoji_events,
                                                    color: Colors.amber,
                                                    size: 18)),
                                            const Text("1RM",
                                                style: TextStyle(
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                          ],
                                          if (s['isMaxWeight'] == true)
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8),
                                                child: Text("Max",
                                                    style: TextStyle(
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  const SizedBox(height: 8),

                                  // Muscles
                                  if (ex['muscles'].isNotEmpty)
                                    Wrap(
                                      spacing: 12,
                                      children: (ex['muscles'] as List<String>)
                                          .take(3)
                                          .map((m) {
                                        final dist = ex['muscleDistribution'][m]
                                                ?.toString() ??
                                            '';
                                        return Text(
                                            "$m${dist.isNotEmpty ? ' $dist%' : ''}",
                                            style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12));
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 100),
                ],
              ),
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
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
