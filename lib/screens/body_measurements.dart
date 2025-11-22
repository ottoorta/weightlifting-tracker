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
  String? photoURL;
  Map<String, String> muscleImages = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMuscleImages();
  }

  Future<void> _loadUserData() async {
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
        photoURL = data['photoURL'];
      });
    }
  }

  Future<void> _loadMuscleImages() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('muscles').get();
    final Map<String, String> images = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name']?.toString().toLowerCase() ?? '';
      final imageUrl = data['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        images[name] = imageUrl;
      }
    }
    if (mounted) setState(() => muscleImages = images);
  }

  String _getMuscleImage(String label) {
    final key = label.toLowerCase();
    return muscleImages[key] ??
        muscleImages.entries
            .firstWhere((e) => e.key.contains(key) || key.contains(e.key),
                orElse: () =>
                    const MapEntry('chest', 'https://via.placeholder.com/50'))
            .value;
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/no_image.png", width: 150),
                  const SizedBox(height: 30),
                  const Text("No measurements yet",
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 30),
                  _buildAddRow(context),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final latest = docs[0].data() as Map<String, dynamic>;
          final previous =
              docs.length > 1 ? docs[1].data() as Map<String, dynamic> : null;
          final date = (latest['date_time'] as Timestamp).toDate();

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
                      image: photoURL != null && photoURL!.isNotEmpty
                          ? NetworkImage(photoURL!)
                          : const AssetImage("assets/no_image.png")
                              as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Add Measurement Row (clean style)
                _buildAddRow(context),

                const SizedBox(height: 40),

                // Measurements
                _buildMeasurementRow("Weight", latest['weight'],
                    previous?['weight'], weightUnit, Icons.monitor_weight),
                _buildMeasurementRow("Body Fat", latest['body_fat'],
                    previous?['body_fat'], "%", Icons.percent),
                _buildMuscleRow(
                    "Waist", latest['waist'], previous?['waist'], measureUnit),
                _buildMuscleRow("Abdomen", latest['abdomen'],
                    previous?['abdomen'], measureUnit),
                _buildMuscleRow(
                    "Chest", latest['chest'], previous?['chest'], measureUnit),
                _buildMuscleRow("Shoulders", latest['shoulders'],
                    previous?['shoulders'], measureUnit),
                _buildMuscleRow("Forearms", latest['forearms'],
                    previous?['forearms'], measureUnit),
                _buildMuscleRow("Biceps", latest['biceps'], previous?['biceps'],
                    measureUnit),
                _buildMuscleRow("Thighs", latest['thighs'], previous?['thighs'],
                    measureUnit),
                _buildMuscleRow("Calves", latest['calves'], previous?['calves'],
                    measureUnit),
                _buildMuscleRow(
                    "Neck", latest['neck'], previous?['neck'], measureUnit),
                _buildMuscleRow("Glutes", latest['glutes'], previous?['glutes'],
                    measureUnit),

                const SizedBox(height: 20),
                Text("Last recorded: ${_formatDate(date)}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddRow(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/add_body_measurements'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_circle, color: Colors.orange, size: 36),
          SizedBox(width: 12),
          Text(
            "Add Body Measurement",
            style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // For Weight & Body Fat (uses icons)
  Widget _buildMeasurementRow(String label, dynamic current, dynamic previous,
      String unit, IconData icon) {
    final currentVal = (current is num) ? current.toDouble() : 0.0;
    final previousVal = (previous is num) ? previous.toDouble() : null;
    final diff = previousVal != null ? currentVal - previousVal : 0.0;
    final isUp = diff > 0;
    final isSame = diff == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 50),
          const SizedBox(width: 16),
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 16))),
          Expanded(
            flex: 2,
            child: Text("${currentVal.toStringAsFixed(1)} $unit",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              Icon(
                  isSame
                      ? Icons.remove
                      : (isUp ? Icons.trending_up : Icons.trending_down),
                  color:
                      isSame ? Colors.grey : (isUp ? Colors.green : Colors.red),
                  size: 20),
              const SizedBox(width: 4),
              Text(
                  isSame ? "0" : "${isUp ? '+' : ''}${diff.toStringAsFixed(1)}",
                  style: TextStyle(
                      color: isSame
                          ? Colors.grey
                          : (isUp ? Colors.green : Colors.red),
                      fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // For all muscle groups (uses real images)
  Widget _buildMuscleRow(
      String label, dynamic current, dynamic previous, String unit) {
    final currentVal = (current is num) ? current.toDouble() : 0.0;
    final previousVal = (previous is num) ? previous.toDouble() : null;
    final diff = previousVal != null ? currentVal - previousVal : 0.0;
    final isUp = diff > 0;
    final isSame = diff == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _getMuscleImage(label),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[800],
                child: const Icon(Icons.fitness_center, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 16))),
          Expanded(
            flex: 2,
            child: Text("${currentVal.toStringAsFixed(1)} $unit",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              Icon(
                  isSame
                      ? Icons.remove
                      : (isUp ? Icons.trending_up : Icons.trending_down),
                  color:
                      isSame ? Colors.grey : (isUp ? Colors.green : Colors.red),
                  size: 20),
              const SizedBox(width: 4),
              Text(
                  isSame ? "0" : "${isUp ? '+' : ''}${diff.toStringAsFixed(1)}",
                  style: TextStyle(
                      color: isSame
                          ? Colors.grey
                          : (isUp ? Colors.green : Colors.red),
                      fontSize: 14)),
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
