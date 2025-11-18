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

    try {
      debugPrint(
          "ThisWeekRecords: Esta semana ${startOfThisWeek.toString().split(' ').first} → ${endOfThisWeek.toString().split(' ').first}");

      final thisWeekSnapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: user.uid)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfThisWeek))
          .where('completedAt', isLessThan: Timestamp.fromDate(endOfThisWeek))
          .get();

      final lastWeekSnapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('uid', isEqualTo: user.uid)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfLastWeek))
          .where('completedAt', isLessThan: Timestamp.fromDate(startOfThisWeek))
          .get();

      double volumeThis = 0, volumeLast = 0;
      int repsThis = 0, repsLast = 0;
      int setsThis = 0, setsLast = 0;
      int durationThis = 0, durationLast = 0;
      int workoutsThisWeek = 0;

      Future<void> _process(QuerySnapshot snapshot, bool isThisWeek) async {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>; // ← CORREGIDO AQUÍ
          final loggedSetsSnap =
              await doc.reference.collection('logged_sets').get();
          if (loggedSetsSnap.docs.isEmpty) {
            debugPrint("IGNORADO workout ${doc.id}: sin logged_sets");
            continue;
          }

          final duration = (data['duration'] as num?)?.toInt() ?? 0;
          final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

          debugPrint(
              "PROCESADO workout ${doc.id} → ${completedAt?.toString().split(' ').first} | ${loggedSetsSnap.docs.length} sets");

          if (isThisWeek) {
            workoutsThisWeek++;
            durationThis += duration;
          } else {
            durationLast += duration;
          }

          for (var set in loggedSetsSnap.docs) {
            final s = set.data() as Map<String, dynamic>;
            final w = (s['weight'] as num?)?.toDouble() ?? 0;
            final r = (s['reps'] as num?)?.toInt() ?? 0;

            if (isThisWeek) {
              volumeThis += w * r;
              repsThis += r;
              setsThis++;
            } else {
              volumeLast += w * r;
              repsLast += r;
              setsLast++;
            }
          }
        }
      }

      await _process(thisWeekSnapshot, true);
      await _process(lastWeekSnapshot, false);

      debugPrint(
          "RESULTADO: $workoutsThisWeek workouts esta semana | Volumen: ${volumeThis.toStringAsFixed(0)} Kg");

      return {
        'volume': volumeThis,
        'volumeDiff': volumeThis - volumeLast,
        'reps': repsThis,
        'repsDiff': repsThis - repsLast,
        'sets': setsThis,
        'setsDiff': setsThis - setsLast,
        'duration': durationThis,
        'durationDiff': durationThis - durationLast,
        'workoutsThisWeek': workoutsThisWeek,
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
        'workoutsThisWeek': 0,
      };

  String _formatDuration(int minutes) {
    if (minutes == 0) return "0h 0min";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "${h}h ${m}min" : "${m}min";
  }

  String _formatChange(dynamic diff, [bool isDuration = false]) {
    if (diff == 0) return "0";
    final abs = diff.abs();
    final prefix = diff > 0 ? "+" : "-";
    if (isDuration) {
      final h = abs ~/ 60;
      final m = abs % 60;
      return h > 0 ? "$prefix${h}h ${m}min" : "$prefix${m}min";
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

        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/workout_records_calendar'),
          child: Container(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("This Week’s Records",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _StatBox(
                          title: "Volume Lifted",
                          value: "${stats['volume'].toStringAsFixed(0)} KG",
                          change: _formatChange(stats['volumeDiff']),
                          isUp: stats['volumeDiff'] >= 0)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatBox(
                          title: "Reps Completed",
                          value: stats['reps'].toString(),
                          change: _formatChange(stats['repsDiff']),
                          isUp: stats['repsDiff'] >= 0)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _StatBox(
                          title: "Workout Time",
                          value: _formatDuration(stats['duration']),
                          change: _formatChange(stats['durationDiff'], true),
                          isUp: stats['durationDiff'] >= 0)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatBox(
                          title: "Sets Completed",
                          value: stats['sets'].toString(),
                          change: _formatChange(stats['setsDiff']),
                          isUp: stats['setsDiff'] >= 0)),
                ]),
                const SizedBox(height: 16),
                Text("$workoutsThisWeek Workouts completed this week",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
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
    return Container(
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
    );
  }
}
