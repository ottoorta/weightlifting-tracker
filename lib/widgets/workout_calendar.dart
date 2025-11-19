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
  DateTime? _selectedDay;

  String _selectedRange = 'Week';
  Set<DateTime> _workoutDays = {};

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
      default: // All Time
        start = DateTime(2020);
        end = DateTime.now().add(const Duration(days: 365));
    }

    final snap = await FirebaseFirestore.instance
        .collection('workouts')
        .where('uid', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final Set<DateTime> days = {};
    for (var doc in snap.docs) {
      final completedAt = (doc['completedAt'] as Timestamp?)?.toDate();
      if (completedAt != null) {
        days.add(
            DateTime(completedAt.year, completedAt.month, completedAt.day));
      }
    }

    if (mounted) {
      setState(() => _workoutDays = days);
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
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Workout Calendar",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Range Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(30),
              ),
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
                      child: Text(
                        range,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Calendar
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
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.orange),
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
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                weekendTextStyle: const TextStyle(color: Colors.orange),
                defaultTextStyle: const TextStyle(color: Colors.white70),
                outsideDaysVisible: false,
                markerDecoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              eventLoader: (day) =>
                  _workoutDays.contains(DateTime(day.year, day.month, day.day))
                      ? [1]
                      : [],
            ),
          ],
        ),
      ),
    );
  }
}
