// lib/widgets/user_progress_stats.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgressStats extends StatelessWidget {
  const UserProgressStats({super.key});

  // ← CAMBIÉ EL NOMBRE DE LA FUNCIÓN
  Future<Map<String, dynamic>> _getLatestWeight() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'current': '—', 'diff': 0.0, 'isUp': false};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('body_measurements')
          .where('uid', isEqualTo: user.uid)
          .orderBy('date_time', descending: true)
          .limit(2)
          .get();

      if (snapshot.docs.isEmpty) {
        // Fallback al peso del users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final weightStr = userDoc['weight']?.toString() ?? "—";
        final weight = double.tryParse(weightStr.replaceAll(' KG', '')) ?? 0.0;
        return {
          'current': '${weight.toStringAsFixed(1)} KG',
          'diff': 0.0,
          'isUp': false
        };
      }

      final latest = snapshot.docs[0].data();
      final previous =
          snapshot.docs.length > 1 ? snapshot.docs[1].data() : null;

      final currentWeight = (latest['weight'] as num).toDouble();
      final previousWeight = previous != null
          ? (previous['weight'] as num).toDouble()
          : currentWeight;

      final diff = currentWeight - previousWeight;
      final isUp = diff > 0;

      return {
        'current': '${currentWeight.toStringAsFixed(1)} KG',
        'diff': diff.abs(),
        'isUp': isUp,
      };
    } catch (e) {
      return {'current': '—', 'diff': 0.0, 'isUp': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  // ← AQUÍ ESTABA EL ERROR: usaba _getUserWeight()
                  future: _getLatestWeight(), // ← AHORA SÍ USA LA FUNCIÓN NUEVA
                  builder: (context, snapshot) {
                    final data = snapshot.data ??
                        {'current': '—', 'diff': 0.0, 'isUp': false};
                    return GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/body_measurements'),
                      child: _ProgressCard(
                        title: "Your Weight",
                        value: data['current'],
                        change: data['diff'],
                        isUp: data['isUp'],
                        icon: Icons.monitor_weight,
                        color: Colors.orange,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProgressCard(
                  title: "Your Strength",
                  value: "255",
                  change: 12,
                  isUp: false,
                  icon: Icons.fitness_center,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  title: "Muscle Recovery",
                  value: "100%",
                  change: 0,
                  isUp: true,
                  icon: Icons.healing,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/strength_score'),
                  child: _ProgressCard(
                    title: "Status",
                    value: "Elite",
                    change: 0,
                    isUp: true,
                    icon: Icons.star,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                          3,
                          (_) => const Icon(Icons.star,
                              color: Colors.amber, size: 16)),
                    ),
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final String value;
  final double change;
  final bool isUp;
  final IconData icon;
  final Widget? suffixIcon;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isUp,
    required this.icon,
    this.suffixIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              if (suffixIcon != null) ...[
                const SizedBox(width: 6),
                suffixIcon!,
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(isUp ? Icons.trending_up : Icons.trending_down,
                  color: isUp ? Colors.green : Colors.red, size: 16),
              const SizedBox(width: 4),
              Text(
                change == 0
                    ? "—"
                    : "${isUp ? '+' : '-'}${change.toStringAsFixed(1)}",
                style: TextStyle(
                    color: isUp ? Colors.green : Colors.red, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
