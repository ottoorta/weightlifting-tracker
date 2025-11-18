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
    final startOfThisWeek = now
        .subtract(Duration(days: now.weekday - 1))
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final endOfThisWeek = startOfThisWeek.add(const Duration(days: 7));

    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

    final thisWeekStartStr =
        "${startOfThisWeek.year}-${startOfThisWeek.month.toString().padLeft(2, '0')}-${startOfThisWeek.day.toString().padLeft(2, '0')}";
    final lastWeekStartStr =
        "${startOfLastWeek.year}-${startOfLastWeek.month.toString().padLeft(2, '0')}-${startOfLastWeek.day.toString().padLeft(2, '0')}";

    try {
      debugPrint("THIS WEEK RECORDS - DEBUG MODE ON");
      debugPrint("Hoy: ${now.toString().split(' ').first}");
      debugPrint("Esta semana: $thisWeekStartStr → ...");
      debugPrint("Semana pasada: $lastWeekStartStr → $thisWeekStartStr");

      // ESTA SEMANA
      final thisWeekSnapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: thisWeekStartStr)
          .get();

      debugPrint(
          "Esta semana: ${thisWeekSnapshot.docs.length} workouts encontrados:");
      for (var doc in thisWeekSnapshot.docs) {
        final data = doc.data();
        debugPrint(
            "  → Workout ID: ${doc.id} | Fecha: ${data['date']} | Duración: ${data['duration']} min | logged_sets: ${doc.reference.collection('logged_sets').path}");
      }

      // SEMANA PASADA
      final lastWeekSnapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: lastWeekStartStr)
          .where('date', isLessThan: thisWeekStartStr)
          .get();

      debugPrint(
          "Semana pasada: ${lastWeekSnapshot.docs.length} workouts encontrados:");
      for (var doc in lastWeekSnapshot.docs) {
        final data = doc.data();
        debugPrint(
            "  → Workout ID: ${doc.id} | Fecha: ${data['date']} | Duración: ${data['duration']} min");
      }

      double volumeThis = 0, volumeLast = 0;
      int repsThis = 0, repsLast = 0;
      int setsThis = 0, setsLast = 0;
      int durationThis = 0, durationLast = 0;

      Future<void> _processWeek(QuerySnapshot snapshot, bool isThisWeek) async {
        for (var doc in snapshot.docs) {
          final loggedSetsSnap =
              await doc.reference.collection('logged_sets').get();
          final duration = (doc['duration'] as num?)?.toInt() ?? 0;

          debugPrint(
              "  Procesando ${loggedSetsSnap.docs.length} sets del workout ${doc.id}");

          for (var setDoc in loggedSetsSnap.docs) {
            final data = setDoc.data();
            final weight = (data['weight'] as num?)?.toDouble() ?? 0;
            final reps = (data['reps'] as num?)?.toInt() ?? 0;

            if (isThisWeek) {
              volumeThis += weight * reps;
              repsThis += reps;
              setsThis++;
              durationThis += duration;
            } else {
              volumeLast += weight * reps;
              repsLast += reps;
              setsLast++;
              durationLast += duration;
            }
          }
        }
      }

      await _processWeek(thisWeekSnapshot, true);
      await _processWeek(lastWeekSnapshot, false);

      final workoutsThisWeek = thisWeekSnapshot.docs.length;
      final workoutsLeft = 3 - workoutsThisWeek;

      debugPrint("RESULTADO FINAL:");
      debugPrint(
          "  Esta semana → Volumen: $volumeThis KG | Reps: $repsThis | Sets: $setsThis | Tiempo: $durationThis min");
      debugPrint(
          "  Semana pasada → Volumen: $volumeLast KG | Reps: $repsLast | Sets: $setsLast | Tiempo: $durationLast min");
      debugPrint(
          "  Diferencia → Volumen: ${volumeThis - volumeLast} | Reps: ${repsThis - repsLast} | Tiempo: ${durationThis - durationLast} min");

      return {
        'volume': volumeThis,
        'volumeDiff': volumeThis - volumeLast,
        'reps': repsThis,
        'repsDiff': repsThis - repsLast,
        'sets': setsThis,
        'setsDiff': setsThis - setsLast,
        'duration': durationThis,
        'workoutsThisWeek': workoutsThisWeek,
        'durationDiff': durationThis - durationLast,
        'workoutsLeft': workoutsLeft.clamp(0, 3),
      };
    } catch (e, s) {
      debugPrint("ERROR CRÍTICO en ThisWeekRecords: $e\n$s");
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

  String _formatChange(dynamic diff, {bool isDuration = false}) {
    if (diff == 0) return "0";
    final abs = diff.abs();
    final prefix = diff > 0 ? "+" : "-";
    if (isDuration) {
      final h = abs ~/ 60;
      final m = abs % 60;
      final time = h > 0 ? "${h}h ${m}min" : "${m}min";
      return "$prefix$time";
    }
    return "$prefix$abs";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getThisWeekStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? _emptyStats();

        final workoutsThisWeek = stats['workoutsThisWeek'] as int? ?? 0;

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
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // Evita que ocupe más espacio del necesario
            children: [
              // Título centrado
              const Text(
                "This Week’s Records",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Primera fila
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      title: "Volume Lifted",
                      value: "${stats['volume'].toStringAsFixed(0)} KG",
                      change: _formatChange(stats['volumeDiff']),
                      isUp: stats['volumeDiff'] >= 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      title: "Reps Completed",
                      value: stats['reps'].toString(),
                      change: _formatChange(stats['repsDiff']),
                      isUp: stats['repsDiff'] >= 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segunda fila
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      title: "Workout Time",
                      value: _formatDuration(stats['duration']),
                      change: _formatChange(stats['durationDiff'],
                          isDuration: true),
                      isUp: stats['durationDiff'] >= 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      title: "Sets Completed",
                      value: stats['sets'].toString(),
                      change: _formatChange(stats['setsDiff']),
                      isUp: stats['setsDiff'] >= 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Workouts completados
              Text(
                "$workoutsThisWeek Workouts completed this week",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
  const _StatBox(
      {required this.title,
      required this.value,
      required this.change,
      required this.isUp});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Icon(isUp ? Icons.trending_up : Icons.trending_down,
                    color: isUp ? Colors.green : Colors.red, size: 18),
                Text(change,
                    style: TextStyle(
                        color: isUp ? Colors.green : Colors.red, fontSize: 13)),
              ])),
        ]),
      ),
    );
  }
}
