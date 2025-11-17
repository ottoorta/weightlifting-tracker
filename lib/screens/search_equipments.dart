// lib/screens/search_equipments.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_custom_equipment.dart';

class SearchEquipmentsScreen extends StatefulWidget {
  const SearchEquipmentsScreen({super.key});

  @override
  State<SearchEquipmentsScreen> createState() => _SearchEquipmentsScreenState();
}

class _SearchEquipmentsScreenState extends State<SearchEquipmentsScreen> {
  List<Map<String, dynamic>> allEquipment = [];
  List<Map<String, dynamic>> filteredEquipment = [];
  String searchQuery = '';
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      allEquipment.clear();
      filteredEquipment.clear();
      _isLoading = true;
    });

    await Future.wait([
      _loadOfficial(),
      _loadCustom(),
    ]);

    _applyFilters();
    setState(() => _isLoading = false);
  }

  Future<void> _loadOfficial() async {
    final snap = await FirebaseFirestore.instance.collection('equipment').get();
    for (var doc in snap.docs) {
      final data = doc.data();
      allEquipment.add({'id': doc.id, 'isCustom': false, ...data});
    }
  }

  Future<void> _loadCustom() async {
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('equipment_custom')
        .where('userId', isEqualTo: user!.uid)
        .get();
    for (var doc in snap.docs) {
      final data = doc.data();
      allEquipment.add({'id': doc.id, 'isCustom': true, ...data});
    }
  }

  void _applyFilters() {
    var filtered = allEquipment;
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        final name = (e['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(searchQuery.toLowerCase());
      }).toList();
    }
    setState(() => filteredEquipment = filtered);
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (v) {
                      searchQuery = v;
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
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.orange),
                    ),
                  ),
                ),

                // Add Custom Equipment
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddCustomEquipmentScreen()),
                    );
                    if (result == true) _loadData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Add Custom Equipment",
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // List – FIX OVERFLOW + IMAGEN SEGURA
                Expanded(
                  child: filteredEquipment.isEmpty
                      ? const Center(
                          child: Text("No equipment found",
                              style: TextStyle(color: Colors.white60)))
                      : ListView.builder(
                          itemCount: filteredEquipment.length,
                          itemBuilder: (context, i) {
                            final eq = filteredEquipment[i];
                            final bool isCustom = eq['isCustom'] == true;
                            final String? imgUrl = eq['imageUrl'] as String?;
                            final String name =
                                (eq['name'] as String?)?.trim() ?? 'Unknown';
                            final String muscles =
                                (eq['muscleGroups'] as String?)?.trim() ??
                                    'None';

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                                border: isCustom
                                    ? Border.all(color: Colors.orange, width: 2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Imagen con fallback seguro
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImage(imgUrl),
                                  ),
                                  const SizedBox(width: 12),

                                  // Texto con overflow controlado
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                                overflow: TextOverflow
                                                    .ellipsis, // FIX OVERFLOW
                                                maxLines: 1,
                                              ),
                                            ),
                                            if (isCustom)
                                              const Icon(Icons.star,
                                                  color: Colors.orange,
                                                  size: 20),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Muscles: $muscles",
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
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
    );
  }

  // FIX: imagen segura contra URLs rotas o vacías
  Widget _buildImage(String? url) {
    if (url == null ||
        url.isEmpty ||
        url.startsWith('file://') ||
        url.trim() == '') {
      return Container(
        width: 70,
        height: 70,
        color: Colors.grey[800],
        child:
            const Icon(Icons.fitness_center, color: Colors.white54, size: 32),
      );
    }

    return Image.network(
      url,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 70,
        height: 70,
        color: Colors.grey[800],
        child:
            const Icon(Icons.fitness_center, color: Colors.white54, size: 32),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 70,
          height: 70,
          color: Colors.grey[800],
          child: const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.orange, strokeWidth: 2))),
        );
      },
    );
  }
}
