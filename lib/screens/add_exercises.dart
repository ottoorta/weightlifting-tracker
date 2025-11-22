// lib/screens/add_exercises.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_custom_exercise.dart';

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

  // FILTERS
  String? selectedMuscle = 'All';
  String? selectedEquipment = 'All';
  List<String> muscleList = [];
  List<String> equipmentList = [];

  final user = FirebaseAuth.instance.currentUser;
  final Map<String, String> _equipmentNameCache = {};

  bool _isLoading = true; // ← NEW: Show loading state

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      allExercises.clear();
      filteredExercises.clear();
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadOfficialExercises(),
        _loadCustomExercises(),
        _loadMuscles(),
        _loadEquipmentList(),
      ]);
    } catch (e) {
      debugPrint("Error loading data: $e");
      // Still show what we have
    }

    // FIXED: Apply filters AFTER all data is loaded
    _applyFilters();

    setState(() => _isLoading = false);
  }

  Future<void> _loadOfficialExercises() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('exercises').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final equipmentIds = data['equipment'] as List<dynamic>? ?? [];

      String equipmentText = "None";
      if (equipmentIds.isNotEmpty) {
        List<String> names = [];
        for (String id in equipmentIds) {
          if (_equipmentNameCache.containsKey(id)) {
            names.add(_equipmentNameCache[id]!);
          } else {
            final eqDoc = await FirebaseFirestore.instance
                .collection('equipment')
                .doc(id)
                .get();
            final name =
                eqDoc.exists ? (eqDoc['name'] ?? 'Unknown') : 'Unknown';
            _equipmentNameCache[id] = name;
            names.add(name);
          }
        }
        equipmentText = names.join(', ');
      }

      allExercises.add({
        'id': doc.id,
        'isCustom': false,
        ...data,
        '_equipmentText': equipmentText,
      });
    }
  }

  Future<void> _loadCustomExercises() async {
    if (user == null) return;

    // Load user's own customs
    final userSnapshot = await FirebaseFirestore.instance
        .collection('exercises_custom')
        .where('userId', isEqualTo: user!.uid)
        .get();

    for (var doc in userSnapshot.docs) {
      final data = doc.data();
      final equipmentIds = data['equipment'] as List<dynamic>? ?? [];
      String equipmentText = "None";
      if (equipmentIds.isNotEmpty) {
        List<String> names = [];
        for (String id in equipmentIds) {
          if (_equipmentNameCache.containsKey(id)) {
            names.add(_equipmentNameCache[id]!);
          } else {
            final eqDoc = await FirebaseFirestore.instance
                .collection('equipment')
                .doc(id)
                .get();
            final name =
                eqDoc.exists ? (eqDoc['name'] ?? 'Unknown') : 'Unknown';
            _equipmentNameCache[id] = name;
            names.add(name);
          }
        }
        equipmentText = names.join(', ');
      }

      allExercises.add({
        'id': doc.id,
        'isCustom': true,
        ...data,
        '_equipmentText': equipmentText,
      });
    }

    // Load public customs from others
    try {
      final publicSnapshot = await FirebaseFirestore.instance
          .collection('exercises_custom')
          .where('isPublic', isEqualTo: true)
          .where('userId', isNotEqualTo: user!.uid)
          .get();

      for (var doc in publicSnapshot.docs) {
        final data = doc.data();
        final equipmentIds = data['equipment'] as List<dynamic>? ?? [];
        String equipmentText = "None";
        if (equipmentIds.isNotEmpty) {
          List<String> names = [];
          for (String id in equipmentIds) {
            if (_equipmentNameCache.containsKey(id)) {
              names.add(_equipmentNameCache[id]!);
            } else {
              final eqDoc = await FirebaseFirestore.instance
                  .collection('equipment')
                  .doc(id)
                  .get();
              final name =
                  eqDoc.exists ? (eqDoc['name'] ?? 'Unknown') : 'Unknown';
              _equipmentNameCache[id] = name;
              names.add(name);
            }
          }
          equipmentText = names.join(', ');
        }

        allExercises.add({
          'id': doc.id,
          'isCustom': true,
          'isPublic': true,
          ...data,
          '_equipmentText': equipmentText,
        });
      }
    } catch (e) {
      debugPrint("Public exercises failed (index may be building): $e");
      // Continue without public exercises
    }
  }

  Future<void> _loadMuscles() async {
    final snap = await FirebaseFirestore.instance.collection('muscles').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() {
      muscleList = ['All', ...names]..sort((a, b) => a == 'All'
          ? -1
          : b == 'All'
              ? 1
              : a.compareTo(b));
    });
  }

  Future<void> _loadEquipmentList() async {
    final snap = await FirebaseFirestore.instance.collection('equipment').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() {
      equipmentList = ['All', 'None', ...names]..sort((a, b) {
          if (a == 'All') return -1;
          if (b == 'All') return 1;
          if (a == 'None') return -1;
          if (b == 'None') return 1;
          return a.compareTo(b);
        });
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = allExercises;

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((ex) {
        final name = (ex['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (selectedMuscle != null && selectedMuscle != 'All') {
      filtered = filtered.where((ex) {
        final muscles = ex['muscles'] as List<dynamic>? ?? [];
        return muscles.contains(selectedMuscle);
      }).toList();

      filtered.sort((a, b) {
        final aMuscles = a['muscles'] as List<dynamic>? ?? [];
        final bMuscles = b['muscles'] as List<dynamic>? ?? [];
        final aIndex = aMuscles.indexOf(selectedMuscle);
        final bIndex = bMuscles.indexOf(selectedMuscle);
        if (aIndex == 0) return -1;
        if (bIndex == 0) return 1;
        return aIndex.compareTo(bIndex);
      });
    }

    if (selectedEquipment != null && selectedEquipment != 'All') {
      if (selectedEquipment == 'None') {
        filtered = filtered.where((ex) {
          final ids = ex['equipment'] as List<dynamic>? ?? [];
          return ids.isEmpty;
        }).toList();
      } else {
        filtered = filtered.where((ex) {
          final ids = ex['equipment'] as List<dynamic>? ?? [];
          return ids.any((id) => _equipmentNameCache[id] == selectedEquipment);
        }).toList();
      }
    }

    setState(() => filteredExercises = filtered);
  }

  void _clearFilters() {
    setState(() {
      selectedMuscle = 'All';
      selectedEquipment = 'All';
      searchQuery = '';
    });
    _applyFilters();
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
        actions: [
          if (selectedMuscle != 'All' ||
              selectedEquipment != 'All' ||
              searchQuery.isNotEmpty)
            TextButton(
                onPressed: _clearFilters,
                child: const Text("Clear",
                    style: TextStyle(color: Colors.orange))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (val) {
                          searchQuery = val;
                          _applyFilters();
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search exercises...",
                          hintStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.orange),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedMuscle,
                              decoration: InputDecoration(
                                labelText: "Muscle",
                                filled: true,
                                fillColor: const Color(0xFF1C1C1E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              dropdownColor: const Color(0xFF1C1C1E),
                              items: muscleList
                                  .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m,
                                          style: const TextStyle(
                                              color: Colors.white))))
                                  .toList(),
                              onChanged: (val) {
                                setState(() => selectedMuscle = val);
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedEquipment,
                              decoration: InputDecoration(
                                labelText: "Equipment",
                                filled: true,
                                fillColor: const Color(0xFF1C1C1E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              dropdownColor: const Color(0xFF1C1C1E),
                              items: equipmentList
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e,
                                          style: const TextStyle(
                                              color: Colors.white))))
                                  .toList(),
                              onChanged: (val) {
                                setState(() => selectedEquipment = val);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const AddCustomExerciseScreen()),
                    );
                    if (result == true) await _loadData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Add Custom Exercise",
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
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
                            final equipmentText =
                                ex['_equipmentText'] ?? 'None';
                            final isCustom = ex['isCustom'] == true;

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('exercises_notes')
                                  .doc('${user?.uid}_${ex['id']}')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final isFavorite = snapshot.hasData &&
                                    snapshot.data!.exists &&
                                    snapshot.data!['favorite'] == true;

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
                                      border: isCustom
                                          ? Border.all(
                                              color: Colors.orange, width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            ex['imageUrl'] ?? '',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                  Icons.fitness_center,
                                                  color: Colors.white54),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    ex['name'] ?? 'Unknown',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                  if (isCustom) ...[
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.star,
                                                        color: Colors.orange,
                                                        size: 16),
                                                  ],
                                                  if (isFavorite) ...[
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.favorite,
                                                        color: Colors.red,
                                                        size: 16),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Muscles: ${(ex['muscles'] as List?)?.join(', ') ?? 'None'}",
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12),
                                              ),
                                              Text(
                                                "Equipment: $equipmentText",
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12),
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
