// lib/screens/search_equipments.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchEquipmentsScreen extends StatefulWidget {
  const SearchEquipmentsScreen({super.key});

  @override
  State<SearchEquipmentsScreen> createState() => _SearchEquipmentsScreenState();
}

class _SearchEquipmentsScreenState extends State<SearchEquipmentsScreen> {
  List<Map<String, dynamic>> allEquipments = [];
  List<Map<String, dynamic>> filteredEquipments = [];
  String searchQuery = '';

  String? selectedMuscleGroup = 'All';
  List<String> muscleGroupList = ['All'];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      allEquipments.clear();
      filteredEquipments.clear();
      _isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('equipment').get();
      final List<Map<String, dynamic>> loaded = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final muscleGroups = data['muscleGroups'] as String? ?? '';
        final groups =
            muscleGroups.split(', ').where((e) => e.isNotEmpty).toList();

        loaded.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'imageUrl': data['imageUrl'] ?? '',
          'muscleGroups': groups,
          '_muscleText': muscleGroups,
        });

        // Collect unique muscle groups
        for (String group in groups) {
          if (!muscleGroupList.contains(group)) {
            muscleGroupList.add(group);
          }
        }
      }

      setState(() {
        allEquipments = loaded;
        muscleGroupList.sort((a, b) => a == 'All'
            ? -1
            : b == 'All'
                ? 1
                : a.compareTo(b));
      });
    } catch (e) {
      debugPrint("Error loading equipment: $e");
    }

    _applyFilters();
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = allEquipments;

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((eq) {
        final name = (eq['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (selectedMuscleGroup != null && selectedMuscleGroup != 'All') {
      filtered = filtered.where((eq) {
        final groups = eq['muscleGroups'] as List<String>? ?? [];
        return groups.contains(selectedMuscleGroup);
      }).toList();
    }

    setState(() => filteredEquipments = filtered);
  }

  void _clearFilters() {
    setState(() {
      selectedMuscleGroup = 'All';
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
        title: const Text("Search Equipment",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (selectedMuscleGroup != 'All' || searchQuery.isNotEmpty)
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
                          hintText: "Search equipment...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedMuscleGroup,
                        decoration: InputDecoration(
                          labelText: "Muscle Group",
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownColor: const Color(0xFF1C1C1E),
                        items: muscleGroupList
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style:
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (val) {
                          selectedMuscleGroup = val;
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),
                // Después del filtro
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: null, // Por ahora deshabilitado
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          "Add Custom Equipment",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: filteredEquipments.isEmpty
                      ? const Center(
                          child: Text("No equipment found",
                              style: TextStyle(color: Colors.white60)))
                      : ListView.builder(
                          itemCount: filteredEquipments.length,
                          itemBuilder: (context, index) {
                            final eq = filteredEquipments[index];
                            final muscleText = eq['_muscleText'] ?? 'None';

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      eq['imageUrl'] ?? '',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.build,
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
                                        Text(
                                          eq['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Muscles: $muscleText",
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.info_outline,
                                      color: Colors.orange, size: 24),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
