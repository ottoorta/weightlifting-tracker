// lib/screens/edit_custom_exercise.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditCustomExerciseScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String exerciseId;

  const EditCustomExerciseScreen({
    super.key,
    required this.exercise,
    required this.exerciseId,
  });

  @override
  State<EditCustomExerciseScreen> createState() =>
      _EditCustomExerciseScreenState();
}

class _EditCustomExerciseScreenState extends State<EditCustomExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _instructionsController;
  late TextEditingController _videoUrlController;

  // Form fields
  String type = 'Weights';
  String? primaryMuscle;
  String? secondaryMuscle;
  String? selectedEquipmentName;
  String? selectedEquipmentId;
  String importance = 'Medium';
  List<String> relatedExercises = [];
  File? _image;
  String? currentImageUrl;
  int? primaryPercent;
  int? secondaryPercent;

  // Dropdown data
  List<String> muscleList = ['None'];
  List<String> equipmentNames = ['None'];
  Map<String, String> equipmentNameToId = {};
  Map<String, String> idToEquipmentName = {};
  List<String> exerciseNames = ['None'];

  bool isLoading = true;
  String? _videoUrlError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _instructionsController = TextEditingController();
    _videoUrlController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    await Future.wait([
      _loadMuscles(),
      _loadEquipment(),
      _loadExerciseNames(),
    ]);

    // Populate form with existing data
    setState(() {
      _nameController.text = widget.exercise['name'] ?? '';
      _instructionsController.text = widget.exercise['instructions'] ?? '';
      _videoUrlController.text = widget.exercise['videoUrl'] ?? '';

      type = widget.exercise['type'] ?? 'Weights';
      importance = widget.exercise['importance'] ?? 'Medium';
      relatedExercises =
          List<String>.from(widget.exercise['relatedExercises'] ?? []);

      currentImageUrl = widget.exercise['imageUrl'];

      // Muscles & Distribution
      final muscles = List<String>.from(widget.exercise['muscles'] ?? []);
      final distribution =
          List<int>.from(widget.exercise['muscleDistribution'] ?? []);

      if (muscles.isNotEmpty) {
        primaryMuscle = muscles[0];
        primaryPercent = distribution.isNotEmpty ? distribution[0] : 80;
      }
      if (muscles.length > 1) {
        secondaryMuscle = muscles[1];
        secondaryPercent =
            distribution.length > 1 ? distribution[1] : (100 - primaryPercent!);
      }

      // Equipment
      final eqIds = List<String>.from(widget.exercise['equipment'] ?? []);
      if (eqIds.isNotEmpty) {
        selectedEquipmentId = eqIds[0];
        selectedEquipmentName = idToEquipmentName[selectedEquipmentId];
      }

      isLoading = false;
    });
  }

  Future<void> _loadMuscles() async {
    final snap = await FirebaseFirestore.instance.collection('muscles').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() => muscleList = ['None', ...names]..sort());
  }

  Future<void> _loadEquipment() async {
    final snap = await FirebaseFirestore.instance.collection('equipment').get();
    final names = <String>[];
    final nameToId = <String, String>{};
    final idToName = <String, String>{};

    for (var doc in snap.docs) {
      final name = doc['name'] as String;
      final id = doc.id;
      names.add(name);
      nameToId[name] = id;
      idToName[id] = name;
    }

    setState(() {
      equipmentNames = ['None', ...names]..sort();
      equipmentNameToId = nameToId;
      idToEquipmentName = idToName;
    });
  }

  Future<void> _loadExerciseNames() async {
    final snap = await FirebaseFirestore.instance.collection('exercises').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() => exerciseNames = ['None', ...names]..sort());
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('custom_exercises')
        .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_image!);
    return await ref.getDownloadURL();
  }

  bool _isValidVideoUrl(String url) {
    if (url.isEmpty) return true;
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return false;
    final lower = trimmed.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('vimeo.com') ||
        lower.contains('.mp4') ||
        lower.contains('.webm') ||
        lower.contains('.mov');
  }

  Future<int?> _showPercentDialog() async {
    final dialogKey = GlobalKey<FormState>();
    String input = primaryPercent?.toString() ?? '80';

    return await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Primary Muscle Percentage',
              style: TextStyle(color: Colors.white)),
          content: Form(
            key: dialogKey,
            child: TextFormField(
              initialValue: input,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Percentage (1-99)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                final p = int.tryParse(val ?? '');
                if (p == null || p < 1 || p > 99) return 'Enter 1–99';
                return null;
              },
              onSaved: (val) => input = val!,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () {
                if (dialogKey.currentState!.validate()) {
                  dialogKey.currentState!.save();
                  Navigator.pop(ctx, int.parse(input));
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    final videoUrl = _videoUrlController.text.trim();
    if (videoUrl.isNotEmpty && !_isValidVideoUrl(videoUrl)) {
      setState(() => _videoUrlError = 'Invalid video URL');
      return;
    } else {
      setState(() => _videoUrlError = null);
    }

    setState(() => isLoading = true);

    final imageUrl = await _uploadImage() ?? currentImageUrl;

    List<String> muscles = [];
    List<int> distribution = [];

    if (primaryMuscle != null && primaryMuscle != 'None') {
      muscles.add(primaryMuscle!);
      distribution.add(primaryPercent ?? 80);
    }
    if (secondaryMuscle != null && secondaryMuscle != 'None') {
      muscles.add(secondaryMuscle!);
      distribution.add(100 - distribution[0]);
    } else if (muscles.isNotEmpty) {
      distribution[0] = 100;
    }

    List<String> equipmentIds = [];
    if (selectedEquipmentName != null && selectedEquipmentName != 'None') {
      final id = equipmentNameToId[selectedEquipmentName];
      if (id != null) equipmentIds.add(id);
    }

    final updatedData = {
      'name': _nameController.text.trim(),
      'type': type,
      'muscles': muscles,
      'muscleDistribution': distribution,
      'equipment': equipmentIds,
      'importance': importance,
      'relatedExercises': relatedExercises.where((e) => e != 'None').toList(),
      'instructions': _instructionsController.text.trim(),
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
    };

    try {
      await FirebaseFirestore.instance
          .collection('exercises_custom')
          .doc(widget.exerciseId)
          .update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Exercise updated!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
        title: const Text("Edit Custom Exercise",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            image: _image != null
                                ? DecorationImage(
                                    image: FileImage(_image!),
                                    fit: BoxFit.cover)
                                : currentImageUrl != null &&
                                        currentImageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(currentImageUrl!),
                                        fit: BoxFit.cover)
                                    : null,
                          ),
                          child: _image == null &&
                                  (currentImageUrl == null ||
                                      currentImageUrl!.isEmpty)
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Colors.orange, size: 40),
                                    Text("Add Image",
                                        style:
                                            TextStyle(color: Colors.white70)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Name of the exercise",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (val) =>
                          val?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: "Exercise Type",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: [
                        'Weights',
                        'Bodyweight',
                        'Cardio',
                        'Stretching',
                        'Plyometrics',
                        'Strongman',
                        'Powerlifting',
                        'Other'
                      ]
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => type = val ?? 'Weights'),
                    ),
                    const SizedBox(height: 16),

                    // Primary Muscle
                    DropdownButtonFormField<String>(
                      value: primaryMuscle,
                      decoration: const InputDecoration(
                        labelText: "Primary Muscle",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: muscleList
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) async {
                        if (val == 'None' || val == null) {
                          setState(() => primaryMuscle = null);
                          return;
                        }
                        final percent = await _showPercentDialog();
                        if (percent == null) {
                          setState(() => primaryMuscle = this.primaryMuscle);
                        } else {
                          setState(() {
                            primaryMuscle = val;
                            primaryPercent = percent;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Secondary Muscle
                    DropdownButtonFormField<String>(
                      value: secondaryMuscle,
                      hint: const Text("Secondary Muscle",
                          style: TextStyle(color: Colors.white70)),
                      decoration: const InputDecoration(
                        labelText: "Secondary Muscle",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: muscleList
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) {
                        if (val == 'None' || val == null) {
                          setState(() => secondaryMuscle = null);
                          return;
                        }
                        if (primaryMuscle == null || primaryPercent == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Set primary muscle first')),
                          );
                          return;
                        }
                        setState(() {
                          secondaryMuscle = val;
                          secondaryPercent = 100 - primaryPercent!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Equipment
                    DropdownButtonFormField<String>(
                      value: selectedEquipmentName,
                      hint: const Text("Equipment",
                          style: TextStyle(color: Colors.white70)),
                      decoration: const InputDecoration(
                        labelText: "Equipment",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: equipmentNames
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedEquipmentName = val),
                    ),
                    const SizedBox(height: 16),

                    // Importance
                    DropdownButtonFormField<String>(
                      value: importance,
                      decoration: const InputDecoration(
                        labelText: "Importance",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: ['High', 'Medium', 'Low']
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text(i,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => importance = val!),
                    ),
                    const SizedBox(height: 16),

                    // Related Exercises
                    DropdownButtonFormField<String>(
                      hint: const Text("Related Exercises",
                          style: TextStyle(color: Colors.white70)),
                      decoration: const InputDecoration(
                        labelText: "Related Exercises",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: exerciseNames
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null &&
                            val != 'None' &&
                            !relatedExercises.contains(val)) {
                          setState(() => relatedExercises.add(val));
                        }
                      },
                    ),
                    if (relatedExercises.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: relatedExercises
                            .map((e) => Chip(
                                  label: Text(e,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  backgroundColor:
                                      Colors.orange.withOpacity(0.3),
                                  deleteIconColor: Colors.orange,
                                  onDeleted: () => setState(
                                      () => relatedExercises.remove(e)),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 16),

                    // Video URL
                    TextFormField(
                      controller: _videoUrlController,
                      decoration: InputDecoration(
                        labelText: "Video URL (optional)",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        errorText: _videoUrlError,
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() => _videoUrlError = null),
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: "Add instructions here",
                        filled: true,
                        fillColor: Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveExercise,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 56),
                        shape: const StadiumBorder(),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Save Changes",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
