// lib/screens/workout_main.dart
import 'package:flutter/material.dart';

class WorkoutMainScreen extends StatelessWidget {
  final Map<String, dynamic> workout;
  final List<Map<String, dynamic>> exercises;

  const WorkoutMainScreen(
      {super.key, required this.workout, required this.exercises});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
            onPressed: () => Navigator.pop(context)),
        title: Text("${_formatDate(workout['date'])}",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.share, color: Colors.orange),
              onPressed: () {})
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coach Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    CircleAvatar(radius: 16),
                    SizedBox(width: 8),
                    Text("Personal Coach: Otto Orta",
                        style: TextStyle(color: Colors.orange))
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                      "Today’s Workout Details: We will focus on maximizing effort on Triceps, Quads and Calves since they are showing weakness...",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Target Muscles
            const Text("Target Muscles",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _muscleChip("Chest", 100, Colors.red),
                  _muscleChip("Triceps", 75, Colors.blue),
                  _muscleChip("Quads", 65, Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBox("Duration", "30 mins"),
                _statBox("Calories", "450 kcal"),
                _statBox("Volume", "2,358 Kg"),
              ],
            ),
            const SizedBox(height: 20),

            // Exercises
            ...exercises.map((ex) => _exerciseCard(ex, context)).toList(),

            const SizedBox(height: 20),
            Row(children: [
              const Checkbox(value: false, onChanged: null),
              const Text("Make Public", style: TextStyle(color: Colors.white))
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.share, color: Colors.orange),
              const SizedBox(width: 8),
              const Text("Share workout",
                  style: TextStyle(color: Colors.orange))
            ]),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 56),
                  shape: const StadiumBorder()),
              child: const Text("START WORKOUT",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _muscleChip(String name, int percent, Color color) => Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(name, style: const TextStyle(color: Colors.white)),
          Text("$percent%",
              style: TextStyle(color: color, fontWeight: FontWeight.bold))
        ]),
      );

  Widget _statBox(String label, String value) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
      ]);

  Widget _exerciseCard(Map<String, dynamic> ex, context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(ex['imageUrl'] ?? '',
                  width: 60, height: 60, fit: BoxFit.cover)),
          title: Text(ex['name'] ?? 'Exercise',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text("4 sets • 10-12 reps • 20 kg",
              style: const TextStyle(color: Colors.white60)),
          trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.orange),
              onPressed: () {}),
          onTap: () => Navigator.pushNamed(context, '/exercise_timer'),
        ),
      );

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    return "${_dayName(d.weekday)} ${d.day}";
  }

  String _dayName(int weekday) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}
