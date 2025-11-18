// lib/screens/workout_records_calendar.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class WorkoutRecordsCalendarScreen extends StatefulWidget {
  const WorkoutRecordsCalendarScreen({super.key});

  @override
  State<WorkoutRecordsCalendarScreen> createState() =>
      _WorkoutRecordsCalendarScreenState();
}

class _WorkoutRecordsCalendarScreenState
    extends State<WorkoutRecordsCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _selectedRange = 'Week';
  Set<DateTime> _workoutDays = {};
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedRange) {
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(2020);
    }

    startDate = startDate.copyWith(hour: 0, minute: 0, second: 0);

    debugPrint("CARGANDO DATOS para rango: $_selectedRange");
    debugPrint("Desde: ${startDate.toString()}");

    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .get();

    final days = <DateTime>{};
    double volume = 0;
    int reps = 0, sets = 0, duration = 0, workouts = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

      if (completedAt == null) {
        debugPrint("IGNORADO workout ${doc.id}: sin completedAt");
        continue;
      }

      if (completedAt.isBefore(startDate)) {
        debugPrint(
            "IGNORADO workout ${doc.id}: fuera del rango (${completedAt.toString().split(' ').first})");
        continue;
      }

      final loggedSetsSnap =
          await doc.reference.collection('logged_sets').get();
      if (loggedSetsSnap.docs.isEmpty) {
        debugPrint("IGNORADO workout ${doc.id}: sin logged_sets");
        continue;
      }

      debugPrint(
          "PROCESANDO workout ${doc.id} del ${completedAt.toString().split(' ').first} | ${loggedSetsSnap.docs.length} sets");

      days.add(DateTime(completedAt.year, completedAt.month, completedAt.day));
      workouts++;

      final workoutDuration = (data['duration'] as num?)?.toInt() ?? 0;
      duration += workoutDuration;

      for (var set in loggedSetsSnap.docs) {
        final s = set.data();
        final w = (s['weight'] as num?)?.toDouble() ?? 0;
        final r = (s['reps'] as num?)?.toInt() ?? 0;
        volume += w * r;
        reps += r;
        sets++;
      }
    }

    debugPrint("RESULTADO FINAL:");
    debugPrint("  Workouts: $workouts");
    debugPrint("  Volumen: ${volume.toStringAsFixed(1)} Kg");
    debugPrint("  Reps: $reps | Sets: $sets | Tiempo: $duration min");

    setState(() {
      _workoutDays = days;
      _stats = {
        'workouts': workouts,
        'volume': volume,
        'reps': reps,
        'sets': sets,
        'duration': duration,
      };
    });
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "$h Hrs $m mins" : "$m mins";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Workout Records and Calendar",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Botones
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Week', 'Month', 'Year', 'All Time'].map((range) {
                final isSelected = _selectedRange == range;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRange = range);
                    _loadData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(range,
                        style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Calendario
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20)),
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) =>
                  setState(() => _calendarFormat = format),
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 18)),
              daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70),
                  weekendStyle: TextStyle(color: Colors.orange)),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.5),
                    shape: BoxShape.circle),
                selectedDecoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                outsideDaysVisible: true,
                weekendTextStyle: const TextStyle(color: Colors.orange),
                defaultTextStyle: const TextStyle(color: Colors.white70),
                disabledTextStyle: const TextStyle(color: Colors.white30),
                markerDecoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              eventLoader: (day) =>
                  _workoutDays.contains(DateTime(day.year, day.month, day.day))
                      ? [1]
                      : [],
            ),
          ),

          const SizedBox(height: 20),

          // Stats con valor + cambio en la misma línea
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildStat("Workouts Performed", "${_stats['workouts'] ?? 0}",
                    "8 compared to last month"),
                _buildStat("Workout Time",
                    _formatDuration(_stats['duration'] ?? 0), "10 mins less"),
                _buildStat(
                    "Max Weight Lifted", "21 Kg", "2 Kg compared to last week",
                    isUp: true),
                _buildStat("Max Volume in a session", "1,733 Kg",
                    "352 Kg compared to last week",
                    isUp: true),
                _buildStat(
                    "Total Volume",
                    "${(_stats['volume'] ?? 0).toStringAsFixed(0)} Kg",
                    "1,352 Kg compared to last week",
                    isUp: true),
                _buildStat("Total Sets Completed", "${_stats['sets'] ?? 0}",
                    "12 compared to last month"),
                _buildStat("Total Reps Completed", "${_stats['reps'] ?? 0}",
                    "25 compared to last month"),
                _buildStat("Max Repetitions in a session", "18 Reps",
                    "3 compared to last month"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String title, String value, String change,
      {bool isUp = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp ? Colors.green : Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(change,
                      style: TextStyle(
                          color: isUp ? Colors.green : Colors.red,
                          fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
