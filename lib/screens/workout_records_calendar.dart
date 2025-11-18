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
  Map<String, dynamic> _currentStats = {};
  Map<String, dynamic> _previousStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    DateTime currentStart, currentEnd, previousStart, previousEnd;

    switch (_selectedRange) {
      case 'Week':
        // Esta semana: lunes a domingo
        currentStart = now
            .subtract(Duration(days: now.weekday - 1))
            .copyWith(hour: 0, minute: 0, second: 0);
        currentEnd =
            currentStart.add(const Duration(days: 7)); // Domingo 23:59:59
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        break;
      case 'Month':
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd =
            DateTime(now.year, now.month + 1, 1); // Primer día del próximo mes
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = currentStart;
        break;
      case 'Year':
        currentStart = DateTime(now.year, 1, 1);
        currentEnd = DateTime(now.year + 1, 1, 1);
        previousStart = DateTime(now.year - 1, 1, 1);
        previousEnd = currentStart;
        break;
      default:
        currentStart = DateTime(2020);
        currentEnd = DateTime.now().add(const Duration(days: 365));
        previousStart = DateTime(2020);
        previousEnd = currentEnd;
    }

    final current = await _fetchStats(currentStart, currentEnd);
    final previous = _selectedRange == 'All Time'
        ? {}
        : await _fetchStats(previousStart, previousEnd);

    setState(() {
      _currentStats = current['stats'];
      _workoutDays = current['days'];
      _previousStats = previous['stats'] ?? {};
    });
  }

  Future<Map<String, dynamic>> _fetchStats(DateTime start, DateTime end) async {
    final user = FirebaseAuth.instance.currentUser!;

    final endExclusive = end
        .copyWith(hour: 0, minute: 0, second: 0)
        .add(const Duration(days: 1));

    debugPrint(
        "RANGO: ${start.toString().split(' ').first} → ${endExclusive.toString().split(' ').first}");

    final snapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(endExclusive))
        .get();

    final days = <DateTime>{};
    double volume = 0;
    int reps = 0, sets = 0, duration = 0, workouts = 0;

    double maxWeight = 0;
    double maxVolumeInSession = 0;
    int maxRepsInSession = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      if (completedAt == null) continue;

      final dateOnly =
          DateTime(completedAt.year, completedAt.month, completedAt.day);
      days.add(dateOnly);

      final loggedSetsSnap =
          await doc.reference.collection('logged_sets').get();
      if (loggedSetsSnap.docs.isEmpty) continue;

      final workoutDuration = (data['duration'] as num?)?.toInt() ?? 0;
      duration += workoutDuration;
      workouts++;

      double sessionVolume = 0;
      for (var set in loggedSetsSnap.docs) {
        final s = set.data();
        final w = (s['weight'] as num?)?.toDouble() ?? 0;
        final r = (s['reps'] as num?)?.toInt() ?? 0;

        // Cálculos generales
        volume += w * r;
        reps += r;
        sets++;

        // Máximos
        if (w > maxWeight) maxWeight = w;
        if (r > maxRepsInSession) maxRepsInSession = r;
        sessionVolume += w * r;
      }

      // Máximo volumen por sesión
      if (sessionVolume > maxVolumeInSession) {
        maxVolumeInSession = sessionVolume;
      }
    }

    return {
      'days': days,
      'stats': {
        'workouts': workouts,
        'volume': volume,
        'reps': reps,
        'sets': sets,
        'duration': duration,
        'maxWeight': maxWeight,
        'maxVolumeSession': maxVolumeInSession,
        'maxRepsSession': maxRepsInSession,
      }
    };
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "$h Hrs $m mins" : "$m mins";
  }

  String _getComparisonText(dynamic current, dynamic previous,
      {bool isDuration = false}) {
    final diff = (current ?? 0) - (previous ?? 0);
    if (diff == 0) return "same as last period";
    final abs = diff.abs();
    final prefix = diff > 0 ? "+" : "-";
    if (isDuration) {
      final h = abs ~/ 60;
      final m = abs % 60;
      final time = h > 0 ? "${h}h ${m}min" : "${m}min";
      return "$prefix$time ${diff > 0 ? "more" : "less"} than last period";
    }
    return "$prefix$abs ${diff > 0 ? "more" : "less"} than last period";
  }

  // ← CORREGIDO: nombre correcto
  Widget _buildStat(String title, String value, String comparison) {
    final isUp = !comparison.contains("less") && !comparison.contains("same");
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
                  Text(comparison,
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

          // Stats con comparaciones reales
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildStat(
                    "Workouts Performed",
                    "${_currentStats['workouts'] ?? 0}",
                    _getComparisonText(
                        _currentStats['workouts'], _previousStats['workouts'])),
                _buildStat(
                    "Workout Time",
                    _formatDuration(_currentStats['duration'] ?? 0),
                    _getComparisonText(
                        _currentStats['duration'], _previousStats['duration'],
                        isDuration: true)),
                _buildStat(
                    "Total Volume",
                    "${(_currentStats['volume'] ?? 0).toStringAsFixed(0)} Kg",
                    _getComparisonText(
                        _currentStats['volume'], _previousStats['volume'])),
                _buildStat(
                    "Total Sets Completed",
                    "${_currentStats['sets'] ?? 0}",
                    _getComparisonText(
                        _currentStats['sets'], _previousStats['sets'])),
                _buildStat(
                    "Total Reps Completed",
                    "${_currentStats['reps'] ?? 0}",
                    _getComparisonText(
                        _currentStats['reps'], _previousStats['reps'])),
                _buildStat(
                    "Max Weight Lifted",
                    "${_currentStats['maxWeight']?.toStringAsFixed(1) ?? 0} Kg",
                    _getComparisonText(_currentStats['maxWeight'],
                        _previousStats['maxWeight'])),
                _buildStat(
                    "Max Volume in a session",
                    "${_currentStats['maxVolumeSession']?.toStringAsFixed(0) ?? 0} Kg",
                    _getComparisonText(_currentStats['maxVolumeSession'],
                        _previousStats['maxVolumeSession'])),
                _buildStat(
                    "Max Repetitions in a session",
                    "${_currentStats['maxRepsSession'] ?? 0} Reps",
                    _getComparisonText(_currentStats['maxRepsSession'],
                        _previousStats['maxRepsSession'])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
