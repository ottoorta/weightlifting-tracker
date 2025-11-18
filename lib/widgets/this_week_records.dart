// lib/widgets/this_week_records.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThisWeekRecords extends StatelessWidget {
  const ThisWeekRecords({super.key});

  Future<Map<String, dynamic>> _getThisWeekStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _emptyStats();

    final now = DateTime.now();
    final startOfWeek = now
        .subtract(Duration(days: now.weekday - 1))
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final weekStartStr =
        "${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}";
    final weekEndStr =
        "${endOfWeek.year}-${endOfWeek.month.toString().padLeft(2, '0')}-${endOfWeek.day.toString().padLeft(2, '0')}";

    try {
      debugPrint("Buscando workouts esta semana: $weekStartStr → $weekEndStr");

      final snapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: weekStartStr)
          .where('date', isLessThan: weekEndStr)
          .get();

      debugPrint("Workouts encontrados esta semana: ${snapshot.docs.length}");

      double volume = 0;
      int reps = 0;
      int sets = 0;
      int duration = 0;

      for (var doc in snapshot.docs) {
        final workoutId = doc.id;
        debugPrint("Procesando workout: $workoutId");

        final loggedSetsSnap =
            await doc.reference.collection('logged_sets').get();
        debugPrint(
            "  → logged_sets encontrados: ${loggedSetsSnap.docs.length}");

        final workoutDuration = (doc['duration'] as num?)?.toInt() ?? 0;
        duration += workoutDuration;

        for (var setDoc in loggedSetsSnap.docs) {
          final data = setDoc.data();
          final weight = (data['weight'] as num?)?.toDouble() ?? 0;
          final r = (data['reps'] as num?)?.toInt() ?? 0;

          volume += weight * r;
          reps += r;
          sets++;
        }
      }

      final workoutsThisWeek = snapshot.docs.length;
      final workoutsLeft = 3 - workoutsThisWeek;

      debugPrint(
          "RESULTADO FINAL → Volumen: $volume KG | Reps: $reps | Sets: $sets | Tiempo: $duration min");

      return {
        'volume': volume,
        'volumeDiff': 0.0,
        'reps': reps,
        'repsDiff': 0,
        'sets': sets,
        'setsDiff': 0,
        'duration': duration,
        'durationDiff': 0,
        'workoutsLeft': workoutsLeft.clamp(0, 3),
      };
    } catch (e, s) {
      debugPrint("ERROR en ThisWeekRecords: $e\n$s");
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() => {
        'volume': 0.0,
        'volumeDiff': 0.0,
        'reps': 0,
        'repsDiff': 0,
        'sets': 0,
        'setsDiff': 0,
        'duration': 0,
        'durationDiff': 0,
        'workoutsLeft': 3,
      };

  String _formatDuration(int minutes) {
    if (minutes == 0) return "0h 0min";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "${h}h ${m}min" : "${m}min";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getThisWeekStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? _emptyStats();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 1),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "This Week’s Records",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatBox(
                    title: "Volume Lifted",
                    value: "${stats['volume'].toStringAsFixed(0)} KG",
                    change: "+0",
                    isUp: true,
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    title: "Reps Completed",
                    value: stats['reps'].toString(),
                    change: "+0",
                    isUp: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatBox(
                    title: "Workout Time",
                    value: _formatDuration(stats['duration']),
                    change: "+0h 0min",
                    isUp: true,
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    title: "Sets Completed",
                    value: stats['sets'].toString(),
                    change: "+0",
                    isUp: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "${stats['workoutsLeft']} Workouts left this week",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title, value, change;
  final bool isUp;

  const _StatBox({
    required this.title,
    required this.value,
    required this.change,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isUp ? Icons.trending_up : Icons.trending_down,
                    color: isUp ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  Text(
                    change,
                    style: TextStyle(
                        color: isUp ? Colors.green : Colors.red, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
