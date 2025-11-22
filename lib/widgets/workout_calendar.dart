// lib/widgets/workout_calendar.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({super.key});

  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  String _selectedRange = 'Week';
  Set<DateTime> _completedDays = {};
  Set<DateTime> _plannedDays = {};

  @override
  void initState() {
    super.initState();
    _loadWorkoutDays();
  }

  Future<void> _loadWorkoutDays() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    DateTime start, end;

    switch (_selectedRange) {
      case 'Week':
        start = now
            .subtract(Duration(days: now.weekday - 1))
            .copyWith(hour: 0, minute: 0);
        end = start.add(const Duration(days: 7));
        break;
      case 'Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case 'Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
      default:
        start = DateTime(2020);
        end = DateTime.now().add(const Duration(days: 365));
    }

    final Set<DateTime> completed = {};
    final Set<DateTime> planned = {};

    // Workouts completados
    final completedSnap = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    for (var doc in completedSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('completedAt') && data['completedAt'] != null) {
        final date = (data['completedAt'] as Timestamp).toDate();
        completed.add(DateTime(date.year, date.month, date.day));
      }
    }

    // Workouts planificados
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final plannedSnap = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: todayStr)
        .get();

    for (var doc in plannedSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('completedAt') && data['completedAt'] != null)
        continue;

      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        planned.add(DateTime(date.year, date.month, date.day));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _completedDays = completed;
        _plannedDays = planned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/workout_records_calendar'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Workout Calendar",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Botones de rango (no interfieren)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(30)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Week', 'Month', 'Year', 'All Time'].map((range) {
                  final isSelected = _selectedRange == range;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedRange = range);
                      _loadWorkoutDays();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(range,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Calendario + CAPA TRANSPARENTE ENCIMA
            Stack(
              children: [
                TableCalendar(
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
                    titleTextStyle:
                        TextStyle(color: Colors.white, fontSize: 18),
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: Colors.orange),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: Colors.orange),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Colors.white70),
                    weekendStyle: TextStyle(color: Colors.orange),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.5),
                        shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    weekendTextStyle: const TextStyle(color: Colors.orange),
                    defaultTextStyle: const TextStyle(color: Colors.white70),
                    outsideDaysVisible: false,
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
                          child: CircleAvatar(
                              radius: 4.5, backgroundColor: Colors.green),
                        );
                      }
                      if (_plannedDays.contains(d)) {
                        return const Positioned(
                          bottom: 6,
                          right: 6,
                          child: CircleAvatar(
                              radius: 4.5, backgroundColor: Colors.orange),
                        );
                      }
                      return null;
                    },
                  ),
                ),

                // ESTA ES LA CLAVE: capa transparente que captura el toque
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => Navigator.pushNamed(
                        context, '/workout_records_calendar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
