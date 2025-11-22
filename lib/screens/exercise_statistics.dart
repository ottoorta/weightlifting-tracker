// lib/screens/exercise_statistics.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExerciseStatisticsScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;

  const ExerciseStatisticsScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  State<ExerciseStatisticsScreen> createState() =>
      _ExerciseStatisticsScreenState();
}

class _ExerciseStatisticsScreenState extends State<ExerciseStatisticsScreen> {
  bool isLoading = true;

  // Estadísticas globales
  int workoutsPerformed = 0;
  double projected1RM = 0.0;
  DateTime? projected1RMDate;
  double maxWeightLifted = 0.0;
  DateTime? maxWeightDate;
  double maxVolumeSession = 0.0;
  DateTime? maxVolumeSessionDate;
  double totalVolume = 0.0;
  int totalReps = 0;
  DateTime? firstWorkoutDate;
  int maxRepsSingleSet = 0;
  DateTime? maxRepsDate;
  DateTime? lastWorkoutDate;

  List<Map<String, dynamic>> history = [];

  // Estados de botones
  bool isFavorite = false;
  bool isDontRecommend = false;
  bool isQueued = false;
  String notes = '';
  final TextEditingController _notesController = TextEditingController();

  String weightUnit = 'Kg';
  late NumberFormat volumeFormat;

  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    volumeFormat = NumberFormat('#,###');
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final Duration difference = DateTime.now().difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays <= 7) return '${difference.inDays} days ago';
    return DateFormat('MMMM do, yyyy').format(date);
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('EEEE, MMMM do, yyyy').format(date);
  }

  Future<void> _toggleFavorite() async {
    setState(() => isFavorite = !isFavorite);
    await _saveNotes();
  }

  Future<void> _toggleDontRecommend() async {
    setState(() => isDontRecommend = !isDontRecommend);
    await _saveNotes();
  }

  Future<void> _toggleQueue() async {
    setState(() => isQueued = !isQueued);
    await _saveNotes();
  }

  Future<void> _saveNotes() async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_${widget.exerciseId}')
        .set({
      'favorite': isFavorite,
      'dontRecommend': isDontRecommend,
      'queued': isQueued,
      'notes': _notesController.text,
    }, SetOptions(merge: true));
  }

  Future<void> _loadData() async {
    if (user == null || widget.exerciseId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Unidad de peso
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userDoc.exists) {
        weightUnit = userDoc.get('weightUnit') == 'LB' ? 'LB' : 'KG';
      }

      // Cargar notas y estados
      final noteDoc = await FirebaseFirestore.instance
          .collection('exercises_notes')
          .doc('${user!.uid}_${widget.exerciseId}')
          .get();
      if (noteDoc.exists) {
        final data = noteDoc.data()!;
        isFavorite = data['favorite'] ?? false;
        isDontRecommend = data['dontRecommend'] ?? false;
        isQueued = data['queued'] ?? false;
        notes = data['notes'] ?? '';
        _notesController.text = notes;
      }

      // === BUSCAR TODOS LOS logged_sets del ejercicio ===
      final setsSnap = await FirebaseFirestore.instance
          .collectionGroup('logged_sets')
          .where('exerciseId', isEqualTo: widget.exerciseId)
          .get();

      if (setsSnap.docs.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Agrupar sets por workout
      Map<String, List<QueryDocumentSnapshot>> setsByWorkout = {};
      for (var doc in setsSnap.docs) {
        final workoutId = doc.reference.parent.parent!.id;
        setsByWorkout.putIfAbsent(workoutId, () => []).add(doc);
      }

      List<Map<String, dynamic>> allSessions = [];

      for (var entry in setsByWorkout.entries) {
        final workoutId = entry.key;
        var setsDocs = entry.value;

        final workoutDoc = await FirebaseFirestore.instance
            .collection('workouts')
            .doc(workoutId)
            .get();

        Timestamp? workoutTs = workoutDoc.get('completedAt') as Timestamp?;
        DateTime workoutDate = workoutTs?.toDate() ??
            (setsDocs.first.get('timestamp') as Timestamp?)?.toDate() ??
            DateTime.now();

        lastWorkoutDate ??= workoutDate;
        if (workoutDate.isAfter(lastWorkoutDate!))
          lastWorkoutDate = workoutDate;
        firstWorkoutDate ??= workoutDate;
        if (workoutDate.isBefore(firstWorkoutDate!))
          firstWorkoutDate = workoutDate;

        workoutsPerformed++;

        double sessionVolume = 0.0;
        double sessionMax1RM = 0.0;
        double sessionMaxWeight = 0.0;
        int sessionMaxReps = 0;
        List<Map<String, dynamic>> sessionSets = [];

        // ORDENAR SETS POR TIMESTAMP (oldest → newest)
        setsDocs.sort((a, b) {
          final Map<String, dynamic>? dataA = a.data() as Map<String, dynamic>?;
          final Map<String, dynamic>? dataB = b.data() as Map<String, dynamic>?;
          final tsA = dataA?['timestamp'] as Timestamp?;
          final tsB = dataB?['timestamp'] as Timestamp?;
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          return tsA.compareTo(tsB);
        });

        for (var setDoc in setsDocs) {
          final data = setDoc.data() as Map<String, dynamic>;
          final double reps = (data['reps'] as num?)?.toDouble() ?? 0.0;
          final double weight = (data['weight'] as num?)?.toDouble() ?? 0.0;

          if (reps <= 0 || weight <= 0) continue;

          final double calc1RM = weight * (1 + reps / 30.0);

          sessionVolume += reps * weight;
          totalVolume += reps * weight;
          totalReps += reps.toInt();

          if (calc1RM > sessionMax1RM) sessionMax1RM = calc1RM;
          if (weight > sessionMaxWeight) sessionMaxWeight = weight;
          if (reps.toInt() > sessionMaxReps) sessionMaxReps = reps.toInt();

          if (calc1RM > projected1RM) {
            projected1RM = calc1RM;
            projected1RMDate = workoutDate;
          }
          if (weight > maxWeightLifted) {
            maxWeightLifted = weight;
            maxWeightDate = workoutDate;
          }
          if (reps.toInt() > maxRepsSingleSet) {
            maxRepsSingleSet = reps.toInt();
            maxRepsDate = workoutDate;
          }

          sessionSets.add({
            'reps': reps.toInt(),
            'weight': weight,
            'calc1RM': calc1RM,
          });
        }

        if (sessionVolume > maxVolumeSession) {
          maxVolumeSession = sessionVolume;
          maxVolumeSessionDate = workoutDate;
        }

        // Marcar récords del workout
        for (var s in sessionSets) {
          final double s1RM = s['calc1RM'] as double;
          final double sWeight = s['weight'] as double;
          if (s1RM >= sessionMax1RM - 0.01) {
            s['isSessionMax1RM'] = true;
          }
          if (sWeight >= sessionMaxWeight - 0.01) {
            s['isSessionMaxWeight'] = true;
          }
        }

        allSessions.add({
          'workoutId': workoutId,
          'date': workoutDate,
          'volume': sessionVolume.round(),
          'sessionMax1RM': sessionMax1RM,
          'sessionMaxWeight': sessionMaxWeight,
          'sets': sessionSets,
        });
      }

      // ORDENAR HISTORIAL: más nuevo → más antiguo
      allSessions.sort((a, b) => b['date'].compareTo(a['date']));

      history = allSessions;
    } catch (e) {
      print('Error loading stats: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildStatRow(String title, String value, String dateText,
      {bool is1RM = false, bool isMaxWeight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (is1RM)
                const Icon(Icons.emoji_events, color: Colors.orange, size: 28),
              if (isMaxWeight)
                const Icon(Icons.emoji_events_outlined,
                    color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ),
              Text(dateText,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.exerciseName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                        isFavorite,
                        Icons.favorite,
                        Icons.favorite_border,
                        Colors.red,
                        'Favorite',
                        _toggleFavorite),
                    _buildActionButton(
                        isDontRecommend,
                        Icons.close,
                        Icons.close,
                        Colors.red,
                        'Don’t Recommend',
                        _toggleDontRecommend),
                    _buildActionButton(isQueued, Icons.repeat, Icons.repeat,
                        Colors.orange, 'Queue', _toggleQueue),
                  ],
                ),
                const SizedBox(height: 32),
                _buildStatRow(
                    'Workouts Performed',
                    workoutsPerformed.toString(),
                    lastWorkoutDate != null
                        ? _formatDate(lastWorkoutDate!)
                        : 'Never'),
                _buildStatRow(
                    'Projected 1 Rep Max (1RM)',
                    '${projected1RM.toStringAsFixed(1)} $weightUnit',
                    projected1RMDate != null
                        ? _formatDate(projected1RMDate!)
                        : 'N/A',
                    is1RM: true),
                _buildStatRow(
                    'Max Weight Lifted',
                    '${maxWeightLifted.toStringAsFixed(1)} $weightUnit',
                    maxWeightDate != null ? _formatDate(maxWeightDate!) : 'N/A',
                    isMaxWeight: true),
                _buildStatRow(
                    'Max Volume in a session',
                    '${volumeFormat.format(maxVolumeSession.round())} $weightUnit',
                    maxVolumeSessionDate != null
                        ? _formatDate(maxVolumeSessionDate!)
                        : 'N/A'),
                _buildStatRow(
                    'Total Volume all time',
                    '${volumeFormat.format(totalVolume.round())} $weightUnit',
                    firstWorkoutDate != null
                        ? 'since ${_formatFullDate(firstWorkoutDate!)}'
                        : ''),
                _buildStatRow(
                    'Total Reps all time',
                    totalReps.toString(),
                    lastWorkoutDate != null
                        ? _formatDate(lastWorkoutDate!)
                        : 'N/A'),
                _buildStatRow(
                    'Max Repetitions in a session',
                    maxRepsSingleSet.toString(),
                    maxRepsDate != null ? _formatDate(maxRepsDate!) : 'N/A'),
                const SizedBox(height: 32),
                const Text('Notes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  onChanged: (_) => _saveNotes(),
                  decoration: InputDecoration(
                    hintText: 'Add your notes here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                ),
                const SizedBox(height: 32),
                const Text('History',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Center(
                      child: Text('No history yet',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 16))),
                ...history.map((h) {
                  final workoutId = h['workoutId'] as String;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/workout_done',
                        arguments: workoutId,
                      );
                    },
                    child: Card(
                      color: const Color(0xFF1C1C1E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatFullDate(h['date']),
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 12),
                            Text(
                                'Volume: ${volumeFormat.format(h['volume'])} $weightUnit',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15)),
                            Text(
                                'One Rep Max (1RM): ${(h['sessionMax1RM'] as double).toStringAsFixed(1)} $weightUnit',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15)),
                            const SizedBox(height: 12),
                            ...(h['sets'] as List).map((set) {
                              final index =
                                  (h['sets'] as List).indexOf(set) + 1;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Text(
                                        'Set $index: ${set['reps']} Reps – ${(set['weight'] as double).toStringAsFixed(1)} $weightUnit',
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    if (set['isSessionMax1RM'] == true)
                                      const Padding(
                                          padding: EdgeInsets.only(left: 10),
                                          child: Icon(Icons.emoji_events,
                                              color: Colors.amber, size: 20)),
                                    if (set['isSessionMaxWeight'] == true)
                                      const Padding(
                                          padding: EdgeInsets.only(left: 10),
                                          child: Icon(
                                              Icons.emoji_events_outlined,
                                              color: Colors.orange,
                                              size: 20)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildActionButton(
      bool isActive,
      IconData activeIcon,
      IconData inactiveIcon,
      Color activeColor,
      String label,
      VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          iconSize: 36,
          icon: Icon(isActive ? activeIcon : inactiveIcon,
              color: isActive ? activeColor : Colors.white70),
          onPressed: onTap,
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
