// lib/screens/exercise_details.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetailsScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailsScreen> createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isFavorite = false;
  bool isInQueue = false;
  bool dontRecommend = false;
  String notes = '';
  final TextEditingController _notesController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final exerciseId = widget.exercise['id'] ?? widget.exercise['docId'];
      if (exerciseId == null) {
        setState(() => isLoading = false);
        return;
      }

      final noteDoc = await FirebaseFirestore.instance
          .collection('exercises_notes')
          .doc('${user!.uid}_$exerciseId')
          .get();

      if (noteDoc.exists) {
        final data = noteDoc.data()!;
        setState(() {
          isFavorite = data['favorite'] == true;
          isInQueue = data['inQueue'] == true;
          dontRecommend = data['dontRecommend'] == true;
          notes = data['notes'] ?? '';
          _notesController.text = notes;
        });
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (user == null) return;
    final newValue = !isFavorite;
    setState(() => isFavorite = newValue);

    final exerciseId = widget.exercise['id'] ?? widget.exercise['docId'];
    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({'favorite': newValue}, SetOptions(merge: true));
  }

  Future<void> _toggleQueue() async {
    if (user == null) return;
    final newValue = !isInQueue;
    setState(() => isInQueue = newValue);

    final exerciseId = widget.exercise['id'] ?? widget.exercise['docId'];
    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({'inQueue': newValue}, SetOptions(merge: true));
  }

  Future<void> _toggleDontRecommend() async {
    if (user == null) return;
    final newValue = !dontRecommend;
    setState(() => dontRecommend = newValue);

    final exerciseId = widget.exercise['id'] ?? widget.exercise['docId'];
    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({'dontRecommend': newValue}, SetOptions(merge: true));
  }

  Future<void> _saveNotes() async {
    if (user == null) return;
    final exerciseId = widget.exercise['id'] ?? widget.exercise['docId'];
    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({'notes': _notesController.text}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.exercise['isCustom'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Exercise Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // IMAGE
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      widget.exercise['imageUrl'] ?? '',
                      height: 400,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[800],
                        child: const Icon(Icons.fitness_center,
                            size: 80, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // NAME
                  Text(
                    widget.exercise['name'] ?? 'Unknown Exercise',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // OPTIONS
                  _buildOption(
                    icon: Icons.info_outline,
                    text: "Instructions and Info",
                    onTap: () => Navigator.pushNamed(context, '/instructions',
                        arguments: widget.exercise),
                  ),
                  _buildOption(
                    icon: Icons.bar_chart,
                    text: "Statistics and History",
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/exercise_statistics',
                      arguments: {
                        'exerciseId':
                            widget.exercise['id'] ?? widget.exercise['docId'],
                        'exerciseName': widget.exercise['name'],
                      },
                    ),
                  ),
                  _buildOption(
                    icon: Icons.note,
                    text: "Notes",
                    onTap: () => _showNotesDialog(),
                  ),
                  _buildOption(
                    icon: Icons.block,
                    text: "Don’t recommend again",
                    onTap: _toggleDontRecommend,
                    color: dontRecommend ? Colors.red : Colors.white70,
                  ),
                  _buildOption(
                    icon: Icons.favorite,
                    text: "Add to Favorites",
                    onTap: _toggleFavorite,
                    color: isFavorite ? Colors.red : Colors.white70,
                  ),
                  _buildOption(
                    icon: Icons.playlist_add,
                    text: "Add to Queue",
                    onTap: _toggleQueue,
                    color: isInQueue ? Colors.orange : Colors.white70,
                  ),
                  if (isCustom)
                    _buildOption(
                      icon: Icons.edit,
                      text: "Edit Custom Exercise",
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/edit_custom_exercise',
                        arguments: {
                          'exerciseId': widget.exercise['id'],
                          'exercise': widget.exercise,
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.orange),
            const SizedBox(width: 16),
            Text(text,
                style: TextStyle(color: color ?? Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Notes", style: TextStyle(color: Colors.orange)),
        content: TextField(
          controller: _notesController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveNotes();
            },
            child: const Text("Save", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
