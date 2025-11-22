// lib/screens/body_measurements.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key});

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  String weightUnit = "KG";
  String measureUnit = "CM";
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserUnitsAndPhoto();
  }

  Future<void> _loadUserUnitsAndPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        weightUnit = data['weightUnit'] ?? "KG";
        measureUnit = data['measureUnit'] ?? "CM";
        photoUrl = data['photoUrl'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Error: No user")));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Body Measurements",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange),
            onPressed: () {
              // TODO: Navigate to edit screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit measurements coming soon!")),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('body_measurements')
            .where('uid', isEqualTo: user.uid)
            .orderBy('date_time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No measurements recorded yet",
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
            );
          }

          final docs = snapshot.data!.docs;
          final latest = docs[0].data() as Map<String, dynamic>;
          final previous =
              docs.length > 1 ? docs[1].data() as Map<String, dynamic> : null;

          final date = (latest['date_time'] as Timestamp).toDate();
          final formattedDate = "${_formatDate(date)}";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Photo
                Container(
                  width: 150,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: photoUrl != null && photoUrl!.isNotEmpty
                          ? NetworkImage(photoUrl!) as ImageProvider
                          : const AssetImage("assets/no_image.png")
                              as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Measurements List
                _buildMeasurementRow("Weight", latest['weight'],
                    previous?['weight'], weightUnit, Icons.monitor_weight),
                _buildMeasurementRow("Body Fat", latest['body_fat'],
                    previous?['body_fat'], "%", Icons.percent),
                _buildMeasurementRow("Waist", latest['waist'],
                    previous?['waist'], measureUnit, Icons.accessibility_new),
                _buildMeasurementRow("Abdomen", latest['abdomen'],
                    previous?['abdomen'], measureUnit, Icons.accessibility),
                _buildMeasurementRow("Chest", latest['chest'],
                    previous?['chest'], measureUnit, Icons.fitness_center),
                _buildMeasurementRow("Shoulders", latest['shoulders'],
                    previous?['shoulders'], measureUnit, Icons.swap_vert),
                _buildMeasurementRow("Forearms", latest['forearms'],
                    previous?['forearms'], measureUnit, Icons.pan_tool),
                _buildMeasurementRow("Biceps", latest['biceps'],
                    previous?['biceps'], measureUnit, Icons.fitness_center),
                _buildMeasurementRow(
                    "Thighs",
                    latest['thighs'],
                    previous?['thighs'],
                    measureUnit,
                    Icons.airline_seat_legroom_extra),
                _buildMeasurementRow(
                    "Calves",
                    latest['calves'],
                    previous?['calves'],
                    measureUnit,
                    Icons.airline_seat_legroom_normal),
                _buildMeasurementRow("Neck", latest['neck'], previous?['neck'],
                    measureUnit, Icons.person_outline),
                _buildMeasurementRow("Glutes", latest['glutes'],
                    previous?['glutes'], measureUnit, Icons.accessibility),

                const SizedBox(height: 20),
                Text("Last recorded: $formattedDate",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeasurementRow(String label, dynamic current, dynamic previous,
      String unit, IconData icon) {
    final currentVal = (current is num) ? current.toDouble() : 0.0;
    final previousVal = (previous is num) ? previous.toDouble() : null;

    final diff = previousVal != null ? currentVal - previousVal : 0.0;
    final isUp = diff > 0;
    final isSame = diff == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 28),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${currentVal.toStringAsFixed(1)} $unit",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Icon(
                isSame
                    ? Icons.remove
                    : (isUp ? Icons.trending_up : Icons.trending_down),
                color:
                    isSame ? Colors.grey : (isUp ? Colors.green : Colors.red),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                isSame ? "0" : "${isUp ? '+' : ''}${diff.toStringAsFixed(1)}",
                style: TextStyle(
                    color: isSame
                        ? Colors.grey
                        : (isUp ? Colors.green : Colors.red),
                    fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }
}
