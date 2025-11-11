// lib/screens/add_exercises.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddExercisesScreen extends StatefulWidget {
  final String workoutId;
  const AddExercisesScreen({super.key, required this.workoutId});

  @override
  State<AddExercisesScreen> createState() => _AddExercisesScreenState();
}

class _AddExercisesScreenState extends State<AddExercisesScreen> {
  List<Map<String, dynamic>> allExercises = [];
  List<Map<String, dynamic>> filteredExercises = [];
  Set<String> selectedIds = {};
  String searchQuery = '';
  String filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('exercises').get();
    final exercises = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    setState(() {
      allExercises = exercises;
      filteredExercises = exercises;
    });
  }

  void _filterExercises() {
    List<Map<String, dynamic>> filtered = allExercises;

    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((ex) =>
              (ex['name'] as String?)
                  ?.toLowerCase()
                  .contains(searchQuery.toLowerCase()) ==
              true)
          .toList();
    }

    setState(() {
      filteredExercises = filtered;
    });
  }

  // Helper to format equipment array
  String _formatEquipment(dynamic equipmentData) {
    if (equipmentData == null) return "None";
    if (equipmentData is List && equipmentData.isEmpty) return "None";
    if (equipmentData is List) {
      return equipmentData.map((e) => e.toString()).join(', ');
    }
    return equipmentData.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Add exercises",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      searchQuery = val;
                      _filterExercises();
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredExercises.isEmpty
                ? const Center(
                    child: Text("No exercises found",
                        style: TextStyle(color: Colors.white60)))
                : ListView.builder(
                    itemCount: filteredExercises.length,
                    itemBuilder: (context, index) {
                      final ex = filteredExercises[index];
                      final isSelected = selectedIds.contains(ex['id']);
                      final equipmentText = _formatEquipment(ex['equipment']);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedIds.remove(ex['id']);
                            } else {
                              selectedIds.add(ex['id'] as String);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  ex['imageUrl'] ?? '',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.fitness_center,
                                        color: Colors.white54),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex['name'] ?? 'Unknown Exercise',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Muscles: ${(ex['muscles'] as List?)?.join(', ') ?? 'None'}",
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                    Text(
                                      "Equipment: $equipmentText",
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: Colors.orange,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      await FirebaseFirestore.instance
                          .collection('workouts')
                          .doc(widget.workoutId)
                          .update({
                        'exerciseIds':
                            FieldValue.arrayUnion(selectedIds.toList()),
                      });
                      if (mounted) Navigator.pop(context, true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.grey,
                minimumSize: const Size(double.infinity, 56),
                shape: const StadiumBorder(),
              ),
              child: Text(
                selectedIds.isEmpty
                    ? "+ Add exercises"
                    : "+ Add ${selectedIds.length} exercise${selectedIds.length > 1 ? 's' : ''}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
