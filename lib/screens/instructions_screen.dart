// lib/screens/instructions_screen.dart
import 'dart:io'; // ADD THIS LINE

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class InstructionsScreen extends StatefulWidget {
  Map<String, dynamic> exercise; // ← Remove final

  InstructionsScreen({super.key, required this.exercise});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late PageController _pageController;
  int _currentPage = 0;

  List<Map<String, dynamic>> muscleData = [];
  List<Map<String, dynamic>> equipmentData = [];
  bool isLoadingMuscles = true;
  bool isLoadingEquipment = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() => _currentPage = _pageController.page?.round() ?? 0);
    });

    _loadVideo();
    _loadMuscles();
    _loadEquipment();
  }

  Future<void> _loadVideo() async {
    final videoUrl = widget.exercise['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController!.initialize();
      _videoController!.setVolume(0);
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.orange,
          handleColor: Colors.orange,
        ),
      );
      setState(() {});
    }
  }

  Widget _buildExerciseImage() {
    final imageUrl = widget.exercise['imageUrl'] as String?;

    // CASE 1: Local file (after picking new image)
    if (imageUrl != null && imageUrl.startsWith('file://')) {
      return Image.file(
        File(imageUrl),
        width: double.infinity,
        height: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }

    // CASE 2: Network URL
    return Image.network(
      imageUrl ?? '',
      width: double.infinity,
      height: 240,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.fitness_center, size: 80, color: Colors.white54),
      ),
    );
  }

  Future<void> _loadMuscles() async {
    final muscleNames = (widget.exercise['muscles'] as List<dynamic>?) ?? [];
    final List<Map<String, dynamic>> loaded = [];

    for (String name in muscleNames) {
      final snap = await FirebaseFirestore.instance
          .collection('muscles')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        loaded.add({
          'name': data['name'] ?? name,
          'imageUrl': data['imageUrl'] ?? '',
        });
      }
    }

    setState(() {
      muscleData = loaded;
      isLoadingMuscles = false;
    });
  }

  Future<void> _loadEquipment() async {
    final equipmentIds = (widget.exercise['equipment'] as List<dynamic>?) ?? [];
    final List<Map<String, dynamic>> loaded = [];

    for (String id in equipmentIds) {
      final doc = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(id)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        loaded.add({
          'name': data['name'] ?? 'Unknown',
          'imageUrl': data['imageUrl'] ?? '',
        });
      }
    }

    setState(() {
      equipmentData = loaded;
      isLoadingEquipment = false;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;
    final totalPages = hasVideo ? 2 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Instructions",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exercise['name'] ?? 'Exercise',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            if (widget.exercise['isCustom'] == true ||
                widget.exercise['userId'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.orange, size: 18),
                  label: const Text("Edit Custom Exercise",
                      style: TextStyle(color: Colors.orange)),
                  onPressed: () async {
                    final exerciseId =
                        widget.exercise['docId'] ?? widget.exercise['id'];
                    if (exerciseId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Error: Exercise ID not found')),
                      );
                      return;
                    }

                    // Fetch fresh data before editing
                    final doc = await FirebaseFirestore.instance
                        .collection('exercises_custom')
                        .doc(exerciseId)
                        .get();

                    if (!doc.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Custom exercise not found')),
                      );
                      return;
                    }

                    final updated = await Navigator.pushNamed(
                      context,
                      '/edit_custom_exercise',
                      arguments: {
                        'exerciseId': exerciseId,
                        'exercise': doc.data()!,
                      },
                    );

                    // RELOAD DATA ON RETURN
                    if (updated == true) {
                      final refreshedDoc = await FirebaseFirestore.instance
                          .collection('exercises_custom')
                          .doc(exerciseId)
                          .get();

                      if (refreshedDoc.exists) {
                        setState(() {
                          widget.exercise.addAll(
                              refreshedDoc.data()!); // Update widget.exercise
                        });
                        _loadVideo(); // Reload video if changed
                        _loadMuscles(); // Reload muscle images
                        _loadEquipment(); // Reload equipment images
                      }
                    }
                  },
                ),
              ),
            const SizedBox(height: 20),

            // IMAGE + VIDEO CAROUSEL
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF1C1C1E),
              ),
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    children: [
                      // MAIN IMAGE - FIXED
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildExerciseImage(),
                      ),
                      // VIDEO
                      if (hasVideo)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Chewie(controller: _chewieController!),
                        ),
                    ],
                  ),
                  if (totalPages > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalPages, (i) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i
                                  ? Colors.orange
                                  : Colors.white38,
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // TARGET MUSCLE DISTRIBUTION
            const Text("Target Muscle Distribution",
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            isLoadingMuscles
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : muscleData.isEmpty
                    ? const Text("None",
                        style: TextStyle(color: Colors.white60))
                    : Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: muscleData
                            .map((m) =>
                                _muscleEquipmentItem(m['imageUrl'], m['name']))
                            .toList(),
                      ),
            const SizedBox(height: 25),

            // EQUIPMENT NEEDED
            const Text("Equipment Needed",
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            isLoadingEquipment
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : equipmentData.isEmpty
                    ? const Text("None",
                        style: TextStyle(color: Colors.white60))
                    : Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: equipmentData
                            .map((e) =>
                                _muscleEquipmentItem(e['imageUrl'], e['name']))
                            .toList(),
                      ),
            const SizedBox(height: 25),

            // INSTRUCTIONS TEXT
            Text(
              "${widget.exercise['name']} Instructions",
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.exercise['instructions'] ?? 'No instructions available.',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _muscleEquipmentItem(String? imageUrl, String name) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16)),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.startsWith('file://')
                      ? Image.file(File(imageUrl), fit: BoxFit.cover)
                      : Image.network(imageUrl, fit: BoxFit.cover),
                )
              : const Icon(Icons.fitness_center, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center),
      ],
    );
  }
}
