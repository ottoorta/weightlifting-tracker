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

  final PageController _pageController = PageController(initialPage: 1);
  int _currentPage = 1; // 0 = Past, 1 = Calendar, 2 = Future

  List<DocumentSnapshot> _pastWorkouts = [];
  List<DocumentSnapshot> _futureWorkouts = [];
  String _gymName = "Home Gym";

  @override
  void initState() {
    super.initState();
    _loadUserGym();
    _loadData();
  }

  Future<void> _loadUserGym() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _gymName =
            (doc.data() as Map<String, dynamic>)['gymName']?.toString() ??
                "Home Gym";
      });
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    DateTime currentStart, currentEnd, previousStart, previousEnd;

    switch (_selectedRange) {
      case 'Week':
        currentStart = now
            .subtract(Duration(days: now.weekday - 1))
            .copyWith(hour: 0, minute: 0, second: 0);
        currentEnd = currentStart.add(const Duration(days: 7));
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        break;
      case 'Month':
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime(now.year, now.month + 1, 1);
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
      _pastWorkouts = current['past'] ?? [];
      _futureWorkouts = current['future'] ?? [];
      _previousStats = previous['stats'] ?? {};
    });
  }

  Future<Map<String, dynamic>> _fetchStats(DateTime start, DateTime end) async {
    final user = FirebaseAuth.instance.currentUser!;
    final endExclusive = end
        .copyWith(hour: 0, minute: 0, second: 0)
        .add(const Duration(days: 1));

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

    final past = <DocumentSnapshot>[];
    final future = <DocumentSnapshot>[];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      final startTime = data['startTime'];

      if (completedAt != null) {
        final dateOnly =
            DateTime(completedAt.year, completedAt.month, completedAt.day);
        days.add(dateOnly);
        past.add(doc);
      } else if (startTime == null) {
        future.add(doc);
      }

      final loggedSetsSnap =
          await doc.reference.collection('logged_sets').get();
      if (loggedSetsSnap.docs.isEmpty) continue;

      final workoutDuration = (data['duration'] as num?)?.toInt() ?? 0;
      duration += workoutDuration;
      workouts++;

      double sessionVolume = 0;
      for (var set in loggedSetsSnap.docs) {
        final s = set.data() as Map<String, dynamic>;
        final w = (s['weight'] as num?)?.toDouble() ?? 0;
        final r = (s['reps'] as num?)?.toInt() ?? 0;

        volume += w * r;
        reps += r;
        sets++;

        if (w > maxWeight) maxWeight = w;
        if (r > maxRepsInSession) maxRepsInSession = r;
        sessionVolume += w * r;
      }

      if (sessionVolume > maxVolumeInSession) {
        maxVolumeInSession = sessionVolume;
      }
    }

    past.sort((a, b) {
      final aTime =
          (a['completedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bTime =
          (b['completedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

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
      },
      'past': past,
      'future': future,
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
          // Botones Week/Month/Year/All Time
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

          // SCROLL HORIZONTAL: Past ← Calendar → Future
          Expanded(
            flex: 3,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildWorkoutCard(
                    _pastWorkouts.isNotEmpty ? _pastWorkouts[0] : null,
                    isPast: true),
                _buildCalendar(),
                _buildWorkoutCard(
                    _futureWorkouts.isNotEmpty ? _futureWorkouts[0] : null,
                    isPast: false),
              ],
            ),
          ),

          // TEXTO DINÁMICO: Back to Calendar si estás en Past o Future
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Izquierda
                if (_currentPage == 0 || _currentPage == 2)
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Icon(Icons.calendar_today, color: Colors.orange),
                      Text(" Back to Calendar",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ]),
                  )
                else
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Icon(Icons.arrow_back_ios, color: Colors.orange),
                      Text(" Past Workouts",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),

                // Derecha
                if (_currentPage == 0 || _currentPage == 2)
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Text("Back to Calendar ",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                      Icon(Icons.calendar_today, color: Colors.orange),
                    ]),
                  )
                else
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(2,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Text("Next Workouts ",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward_ios, color: Colors.orange),
                    ]),
                  ),
              ],
            ),
          ),

          // STATS
          Expanded(
            flex: 2,
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

  Widget _buildCalendar() {
    return Container(
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
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
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
              color: Colors.orange.withOpacity(0.5), shape: BoxShape.circle),
          selectedDecoration:
              const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          outsideDaysVisible: true,
          weekendTextStyle: const TextStyle(color: Colors.orange),
          defaultTextStyle: const TextStyle(color: Colors.white70),
          disabledTextStyle: const TextStyle(color: Colors.white30),
          markerDecoration:
              const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        ),
        eventLoader: (day) =>
            _workoutDays.contains(DateTime(day.year, day.month, day.day))
                ? [1]
                : [],
      ),
    );
  }

  Widget _buildWorkoutCard(DocumentSnapshot? workout, {required bool isPast}) {
    if (workout == null) {
      return Center(
          child: Text(isPast ? "No past workouts" : "No upcoming workouts",
              style: const TextStyle(color: Colors.white70, fontSize: 18)));
    }

    final data = workout.data() as Map<String, dynamic>;
    final completedAt =
        (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = "${_formatDate(completedAt)}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20)),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadWorkoutDetails(workout),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));

          final details = snapshot.data!;
          final sets = details['sets'] as List<Map<String, dynamic>>;
          final volume = details['volume'] as double;
          final effort = _getEffort(
              sets.map((s) => s['setDoc'] as DocumentSnapshot).toList());
          final muscles = details['muscles'] as String;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date: $dateStr",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text("At: $_gymName",
                    style: const TextStyle(color: Colors.white70)),
                Text("Effort: $effort",
                    style: TextStyle(
                        color: effort == "High"
                            ? Colors.red
                            : effort == "Medium"
                                ? Colors.orange
                                : Colors.green,
                        fontWeight: FontWeight.bold)),
                Text("Volume: ${volume.toStringAsFixed(0)} Kg",
                    style: const TextStyle(color: Colors.white)),
                Text("Exercises: ${sets.length}",
                    style: const TextStyle(color: Colors.white)),
                Text(
                    "Total time: ${_formatDuration((data['duration'] as num?)?.toInt() ?? 0)}",
                    style: const TextStyle(color: Colors.white)),
                Text("Muscles: $muscles",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                ...sets.map((s) => Text("• ${s['name']}",
                    style: const TextStyle(color: Colors.white70))),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadWorkoutDetails(
      DocumentSnapshot workout) async {
    final loggedSetsSnap =
        await workout.reference.collection('logged_sets').get();
    double volume = 0;
    final List<Map<String, dynamic>> sets = [];
    final Set<String> muscles = {};

    for (var setDoc in loggedSetsSnap.docs) {
      final s = setDoc.data() as Map<String, dynamic>;
      final exerciseId = s['exerciseId'] as String?;
      final w = (s['weight'] as num?)?.toDouble() ?? 0;
      final r = (s['reps'] as num?)?.toInt() ?? 0;
      volume += w * r;

      String name = "Unknown Exercise";
      if (exerciseId != null) {
        final exDoc = await FirebaseFirestore.instance
            .collection('exercises')
            .doc(exerciseId)
            .get();
        if (exDoc.exists) {
          name = exDoc['name'] ?? "Unknown";
          final mList = exDoc['muscles'] as List<dynamic>?;
          if (mList != null && mList.isNotEmpty) {
            muscles.add(mList[0].toString());
          }
        }
      }

      sets.add({'name': name, 'setDoc': setDoc});
    }

    return {
      'sets': sets,
      'volume': volume,
      'muscles': muscles.isEmpty ? "Various" : muscles.join(", "),
    };
  }

  String _getEffort(List<DocumentSnapshot> sets) {
    if (sets.isEmpty) return "Medium";
    double totalRir = 0;
    int count = 0;
    for (var set in sets) {
      final rir = (set['rir'] as num?)?.toDouble();
      if (rir != null) {
        totalRir += rir;
        count++;
      }
    }
    if (count == 0) return "Medium";
    final avg = totalRir / count;
    if (avg <= 1) return "High";
    if (avg <= 3) return "Medium";
    return "Low";
  }

  String _formatDate(DateTime date) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return "${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day} ${date.year}";
  }

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
}
