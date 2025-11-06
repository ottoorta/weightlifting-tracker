// lib/screens/your_gym_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class YourGymScreen extends StatefulWidget {
  const YourGymScreen({super.key});
  @override
  State<YourGymScreen> createState() => _YourGymScreenState();
}

class _YourGymScreenState extends State<YourGymScreen> {
  final _gymNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _filter = 'Muscle Group';
  List<String> _selectedEquipment = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset('assets/images/iron_background.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity),
          Container(color: Colors.black.withOpacity(0.6)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('We want to know about your',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('usual workout place',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 8),
                      Text('And what kind of equipment do you have available.',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                // Gym Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _gymNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Home Gym',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30))),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Search Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Search and select available equipment',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 12),

                // Filter Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _filterButton('Muscle Group', _filter == 'Muscle Group'),
                      const SizedBox(width: 12),
                      _filterButton(
                          'Equipment Name', _filter == 'Equipment Name'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30))),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Equipment List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('equipment')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.orange));
                      final docs = snapshot.data!.docs;

                      final filtered = docs.where((doc) {
                        final data = doc.data() as Map;
                        final name = data['name'].toString().toLowerCase();
                        final muscles =
                            data['muscleGroups'].toString().toLowerCase();
                        final query = _searchController.text.toLowerCase();
                        return name.contains(query) || muscles.contains(query);
                      }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final data = filtered[i].data() as Map;
                          final id = filtered[i].id;
                          final isSelected = _selectedEquipment.contains(id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                        image: NetworkImage(data['imageUrl']),
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(data['name'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      Text(data['muscleGroups'],
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  activeColor: Colors.orange,
                                  onChanged: (v) {
                                    setState(() {
                                      v!
                                          ? _selectedEquipment.add(id)
                                          : _selectedEquipment.remove(id);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Continue
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: _createGymProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Create Gym Profile and Continue →',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                const Center(
                    child: Text('You can always edit this information later.',
                        style: TextStyle(color: Colors.orange))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.orange : Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _createGymProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'gymName':
          _gymNameController.text.isEmpty ? 'My Gym' : _gymNameController.text,
      'gymEquipment': _selectedEquipment,
    });

    // Auto-navigate: Your Gym → Forging Exp (3s) → Home
    Navigator.pushNamed(context, '/forging_exp');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    });
  }
}
