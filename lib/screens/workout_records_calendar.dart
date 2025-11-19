// lib/screens/workout_records_calendar.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'workout_done.dart';

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

  String _selectedRange = 'Week';
  Set<DateTime> _completedDays = {};
  Set<DateTime> _plannedDays = {};

  Map<String, dynamic> _currentStats = {};
  Map<String, dynamic> _previousStats = {};

  final PageController _pageController = PageController(initialPage: 1);
  int _currentPage = 1;

  List<DocumentSnapshot> _pastWorkouts = [];
  List<DocumentSnapshot> _futureWorkouts = [];
  String _gymName = "Home Gym";

  int _currentPastIndex = 0;

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
        final weekday = now.weekday;
        currentStart = now
            .subtract(Duration(days: weekday - 1))
            .copyWith(hour: 0, minute: 0, second: 0);
        currentEnd = currentStart
            .add(const Duration(days: 7)); // lunes siguiente (exclusivo)
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

    // Limpiar estado anterior
    setState(() {
      _currentStats = {};
      _previousStats = {};
    });

    final current = await _fetchStats(currentStart, currentEnd);
    final previous = _selectedRange == 'All Time'
        ? {'stats': {}}
        : await _fetchStats(previousStart, previousEnd);

    if (!mounted) return;

    setState(() {
      _currentStats = current['stats'];
      _previousStats = previous['stats'] ?? {};
      _completedDays = current['completedDays'] ?? {};
      _plannedDays = current['plannedDays'] ?? {};
      _pastWorkouts = current['past'] ?? [];
      _futureWorkouts = current['future'] ?? [];
      _currentPastIndex = 0;
    });
  }

  Future<Map<String, dynamic>> _fetchStats(DateTime start, DateTime end) async {
    final user = FirebaseAuth.instance.currentUser!;

    debugPrint(
        "Fetching stats from ${start.toString().split(' ')[0]} to ${end.toString().split(' ')[0]}");

    final completedSnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final futureSnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('date',
            isGreaterThanOrEqualTo:
                "${todayStart.year}-${todayStart.month.toString().padLeft(2, '0')}-${todayStart.day.toString().padLeft(2, '0')}")
        .get();

    final Set<DateTime> completedDays = {};
    final Set<DateTime> plannedDays = {};

    double volume = 0;
    int reps = 0, sets = 0, duration = 0, workouts = 0;
    double maxWeight = 0;
    double maxVolumeInSession = 0;
    int maxRepsInSession = 0;

    final past = <DocumentSnapshot>[];
    final future = <DocumentSnapshot>[];

    debugPrint("Found ${completedSnapshot.docs.length} completed workouts");

    for (var doc in completedSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      if (completedAt == null) continue;

      final dateOnly =
          DateTime(completedAt.year, completedAt.month, completedAt.day);
      completedDays.add(dateOnly);
      past.add(doc);

      final loggedSetsSnap =
          await doc.reference.collection('logged_sets').get();
      debugPrint(
          "  Workout ${doc.id} (${dateOnly.toString().split(' ')[0]}) → ${loggedSetsSnap.docs.length} sets");

      final workoutDuration = (data['duration'] as num?)?.toInt() ?? 0;
      duration += workoutDuration;
      workouts++;

      double sessionVolume = 0;
      int workoutReps = 0;

      for (var set in loggedSetsSnap.docs) {
        final s = set.data() as Map<String, dynamic>;
        final w = (s['weight'] as num?)?.toDouble() ?? 0;
        final r = (s['reps'] as num?)?.toInt() ?? 0;

        if (w > 0 && r > 0) {
          volume += w * r;
          reps += r;
          sets++;
          sessionVolume += w * r;
          workoutReps += r;

          if (w > maxWeight) maxWeight = w;
          if (r > maxRepsInSession) maxRepsInSession = r;
        }
      }

      debugPrint(
          "    → Reps: $workoutReps | Volume: ${sessionVolume.toStringAsFixed(0)} kg");

      if (sessionVolume > maxVolumeInSession) {
        maxVolumeInSession = sessionVolume;
      }
    }

    for (var doc in futureSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['completedAt'] != null) continue;

      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);
        plannedDays.add(dateOnly);
        future.add(doc);
      } catch (_) {}
    }

    past.sort((a, b) {
      final aTime =
          (a['completedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bTime =
          (b['completedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    debugPrint(
        "TOTAL → Workouts: $workouts | Sets: $sets | Reps: $reps | Volume: ${volume.toStringAsFixed(0)} kg");

    return {
      'completedDays': completedDays,
      'plannedDays': plannedDays,
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

  Future<String> _getExerciseName(String exerciseId) async {
    var doc = await FirebaseFirestore.instance
        .collection('exercises')
        .doc(exerciseId)
        .get();
    if (doc.exists) return doc['name'] ?? "Unknown Exercise";

    doc = await FirebaseFirestore.instance
        .collection('exercises_custom')
        .doc(exerciseId)
        .get();
    return doc.exists ? (doc['name'] ?? "Custom Exercise") : "Unknown Exercise";
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes == 0) return "To be completed";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "$h Hrs $m mins" : "$m mins";
  }

  String _getComparisonText(dynamic current, dynamic previous,
      {bool isDuration = false}) {
    final currentValue = (current is num) ? current.toDouble() : 0.0;
    final previousValue = (previous is num) ? previous.toDouble() : 0.0;
    final diff = currentValue - previousValue;

    if (diff == 0) return "same as last period";

    final isUp = diff > 0;
    final absDiff = diff.abs();

    String changeText;
    if (isDuration) {
      final hours = absDiff ~/ 60;
      final minutes = (absDiff % 60).toInt();
      changeText = hours > 0 ? "${hours}h ${minutes}min" : "${minutes}min";
    } else {
      changeText = absDiff % 1 == 0
          ? absDiff.toInt().toString()
          : absDiff.toStringAsFixed(1);
    }

    final direction = isUp ? "more" : "less";
    final prefix = isUp ? "+" : "-";

    return "$prefix$changeText $direction than last period";
  }

  double _estimate1RM(double weight, int reps) {
    if (reps >= 37 || weight <= 0) return weight;
    return weight * 36 / (37 - reps);
  }

  @override
  Widget build(BuildContext context) {
    final currentWorkout = _currentPage == 0 && _pastWorkouts.isNotEmpty
        ? _pastWorkouts[_currentPastIndex]
        : (_currentPage == 2 && _futureWorkouts.isNotEmpty
            ? _futureWorkouts[0]
            : null);

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
          Expanded(
            flex: 3,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildWorkoutCard(currentWorkout, isPast: true),
                _buildCalendar(),
                _buildWorkoutCard(currentWorkout, isPast: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage == 1)
                  GestureDetector(
                    onTap: () {
                      _currentPastIndex = 0;
                      _pageController.animateToPage(0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease);
                    },
                    child: const Row(children: [
                      Icon(Icons.arrow_back_ios, color: Colors.orange),
                      SizedBox(width: 4),
                      Text("Past Workouts",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ]),
                  )
                else if (_currentPage == 0 &&
                    _currentPastIndex < _pastWorkouts.length - 1)
                  GestureDetector(
                    onTap: () => setState(() => _currentPastIndex++),
                    child: const Row(children: [
                      Icon(Icons.arrow_back_ios, color: Colors.orange),
                      SizedBox(width: 4),
                      Text("Past Workouts",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ]),
                  )
                else if (_currentPage != 1)
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Icon(Icons.calendar_today, color: Colors.orange),
                      SizedBox(width: 4),
                      Text("Back to Calendar",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ]),
                  ),
                if (_currentPage == 1)
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(2,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Text("Next Workouts ",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.orange),
                    ]),
                  )
                else if (_currentPage == 0)
                  GestureDetector(
                    onTap: () => _pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease),
                    child: const Row(children: [
                      Text("Back to Calendar ",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(width: 4),
                      Icon(Icons.calendar_today, color: Colors.orange),
                    ]),
                  ),
              ],
            ),
          ),
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
                    _formatDuration(_currentStats['duration']),
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
        ),
        eventLoader: (day) {
          final d = DateTime(day.year, day.month, day.day);
          if (_completedDays.contains(d) || _plannedDays.contains(d))
            return ['event'];
          return [];
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final d = DateTime(date.year, date.month, date.day);
            if (_completedDays.contains(d)) {
              return const Positioned(
                  bottom: 6,
                  right: 6,
                  child:
                      CircleAvatar(radius: 4.5, backgroundColor: Colors.green));
            }
            if (_plannedDays.contains(d)) {
              return const Positioned(
                  bottom: 6,
                  right: 6,
                  child: CircleAvatar(
                      radius: 4.5, backgroundColor: Colors.orange));
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(DocumentSnapshot? workout, {required bool isPast}) {
    if (workout == null) {
      return Center(
        child: Text(
          isPast ? "No past workouts" : "No upcoming workouts",
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    final data = workout.data() as Map<String, dynamic>;
    final dateStr = data['date']?.toString() ?? "Unknown Date";
    final workoutId = workout.id; // ← UID del workout

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20)),
      child: FutureBuilder<Map<String, dynamic>>(
        future: isPast
            ? _loadPastWorkoutDetails(workout)
            : _loadFutureWorkoutDetails(workout),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          final details = snapshot.data!;
          final exercises = details['exercises'] as List<Map<String, dynamic>>;
          final volume = details['volume'] as double;
          final effort = details['effort'] as String;
          final muscles = details['muscles'] as String;
          final duration = details['duration'] as int?;

          return GestureDetector(
            onTap: isPast
                ? () {
                    Navigator.pushNamed(
                      context,
                      '/workout_done',
                      arguments: workoutId, // ← pasa el ID como argumento
                    );
                  }
                : null, // Future workouts no hacen nada al tocar
            child: Container(
              color: Colors.transparent,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRichText("Date: ", dateStr, valueBold: true),
                    _buildRichText("At: ", _gymName),
                    _buildRichText("Effort: ", effort,
                        valueColor: effort == "High"
                            ? Colors.red
                            : effort == "Medium"
                                ? Colors.orange
                                : Colors.green),
                    _buildRichText(
                        "Volume: ", "${volume.toStringAsFixed(0)} Kg"),
                    _buildRichText("Exercises: ", "${exercises.length}"),
                    _buildRichText("Total time: ", _formatDuration(duration)),
                    _buildRichText("Muscles: ", muscles),
                    const SizedBox(height: 16),

                    // ← Lista de ejercicios con scroll propio
                    SizedBox(
                      height: exercises.length * 72.0,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final e = exercises[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("• ${e['name']}",
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                if (e['sets'] != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                      "Sets: ${e['sets']}  •  Vol: ${e['volume'].toStringAsFixed(0)} Kg  •  1RM: ${e['1rm'].toStringAsFixed(1)} Kg  •  Max: ${e['maxWeight'].toStringAsFixed(1)} Kg",
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ← Helper para RichText uniforme
  Widget _buildRichText(String label, String value,
      {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 16),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadPastWorkoutDetails(
      DocumentSnapshot workout) async {
    final data = workout.data() as Map<String, dynamic>;
    final exerciseIds = List<String>.from(data['exerciseIds'] ?? []);
    final loggedSetsSnap =
        await workout.reference.collection('logged_sets').get();

    double totalVolume = 0;
    final List<Map<String, dynamic>> exercises = [];
    final Set<String> muscles = {};

    // Acumular datos por ejercicio
    final Map<String, Map<String, dynamic>> exerciseData = {};

    for (var setDoc in loggedSetsSnap.docs) {
      final s = setDoc.data() as Map<String, dynamic>;
      final exerciseId = s['exerciseId'] as String?;
      final w = (s['weight'] as num?)?.toDouble() ?? 0;
      final r = (s['reps'] as num?)?.toInt() ?? 0;

      if (exerciseId == null || w <= 0 || r <= 0) continue;

      totalVolume += w * r;

      if (!exerciseData.containsKey(exerciseId)) {
        exerciseData[exerciseId] = {
          'sets': 0,
          'volume': 0.0,
          'maxWeight': 0.0,
          'best1RM': 0.0,
        };
      }

      final stats = exerciseData[exerciseId]!;
      stats['sets'] = (stats['sets'] as int) + 1;
      stats['volume'] = (stats['volume'] as double) + (w * r);
      if (w > stats['maxWeight']) stats['maxWeight'] = w;

      final estimated1RM = _estimate1RM(w, r);
      if (estimated1RM > stats['best1RM']) stats['best1RM'] = estimated1RM;
    }

    // Procesar ejercicios en orden original
    for (var id in exerciseIds) {
      final exerciseId = id.toString();
      if (exerciseData.containsKey(exerciseId)) {
        final name = await _getExerciseName(exerciseId);
        final stats = exerciseData[exerciseId]!;

        // Músculo principal
        var doc = await FirebaseFirestore.instance
            .collection('exercises')
            .doc(exerciseId)
            .get();
        if (doc.exists) {
          final mList = doc['muscles'] as List<dynamic>?;
          if (mList != null && mList.isNotEmpty)
            muscles.add(mList[0].toString());
        } else {
          doc = await FirebaseFirestore.instance
              .collection('exercises_custom')
              .doc(exerciseId)
              .get();
          if (doc.exists) {
            final mList = doc['muscles'] as List<dynamic>?;
            if (mList != null && mList.isNotEmpty)
              muscles.add(mList[0].toString());
          }
        }

        exercises.add({
          'name': name,
          'sets': stats['sets'],
          'volume': stats['volume'],
          '1rm': stats['best1RM'],
          'maxWeight': stats['maxWeight'],
        });
      }
    }

    // Effort basado en RIR promedio
    String effort = "Medium";
    double totalRir = 0;
    int rirCount = 0;
    for (var set in loggedSetsSnap.docs) {
      final rir = (set['rir'] as num?)?.toDouble();
      if (rir != null) {
        totalRir += rir;
        rirCount++;
      }
    }
    if (rirCount > 0) {
      final avg = totalRir / rirCount;
      effort = avg <= 1
          ? "High"
          : avg <= 3
              ? "Medium"
              : "Low";
    }

    return {
      'exercises': exercises,
      'volume': totalVolume,
      'effort': effort,
      'muscles': muscles.isEmpty ? "Various" : muscles.join(", "),
      'duration': (data['duration'] as num?)?.toInt(),
    };
  }

  Future<Map<String, dynamic>> _loadFutureWorkoutDetails(
      DocumentSnapshot workout) async {
    final data = workout.data() as Map<String, dynamic>;
    final exerciseIds = List<String>.from(data['exerciseIds'] ?? []);

    final List<Map<String, dynamic>> exercises = [];
    final Set<String> muscles = {};

    for (var id in exerciseIds) {
      final name = await _getExerciseName(id);
      exercises.add({'name': name});

      final doc = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .get();
      if (doc.exists) {
        final mList = doc['muscles'] as List<dynamic>?;
        if (mList != null && mList.isNotEmpty) muscles.add(mList[0].toString());
      } else {
        final customDoc = await FirebaseFirestore.instance
            .collection('exercises_custom')
            .doc(id)
            .get();
        if (customDoc.exists) {
          final mList = customDoc['muscles'] as List<dynamic>?;
          if (mList != null && mList.isNotEmpty)
            muscles.add(mList[0].toString());
        }
      }
    }

    return {
      'exercises': exercises,
      'volume': 0.0,
      'effort': "To be calculated",
      'muscles': muscles.isEmpty ? "To be determined" : muscles.join(", "),
      'duration': null,
    };
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
