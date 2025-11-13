// lib/screens/add_custom_exercise.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddCustomExerciseScreen extends StatefulWidget {
  const AddCustomExerciseScreen({super.key});

  @override
  State<AddCustomExerciseScreen> createState() =>
      _AddCustomExerciseScreenState();
}

class _AddCustomExerciseScreenState extends State<AddCustomExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();

  String name = '';
  String type = 'Weights';
  String? primaryMuscle;
  String? secondaryMuscle;
  String? selectedEquipmentName; // Dropdown shows name
  String? selectedEquipmentId; // Save ID
  String importance = 'Medium';
  List<String> relatedExercises = [];
  String instructions = '';
  String videoUrl = '';
  File? _image;

  // NEW: For muscle distribution
  int? primaryPercent;
  int? secondaryPercent;

  List<String> muscleList = ['None'];
  List<String> equipmentNames = ['None']; // For dropdown
  Map<String, String> equipmentNameToId = {}; // Name -> ID map
  List<String> exerciseNames = ['None'];
  bool isLoading = true;

  // For video URL validation feedback
  String? _videoUrlError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMuscles(),
      _loadEquipment(), // Updated to load IDs
      _loadExerciseNames(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> _loadMuscles() async {
    final snap = await FirebaseFirestore.instance.collection('muscles').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() => muscleList = ['None', ...names]..sort());
  }

  // UPDATED: Load equipment names and map to IDs
  Future<void> _loadEquipment() async {
    final snap = await FirebaseFirestore.instance.collection('equipment').get();
    final names = <String>[];
    final nameToId = <String, String>{};
    for (var doc in snap.docs) {
      final name = doc['name'] as String;
      names.add(name);
      nameToId[name] = doc.id;
    }
    setState(() {
      equipmentNames = ['None', ...names]..sort();
      equipmentNameToId = nameToId;
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

  // Validate video URL format
  bool _isValidVideoUrl(String url) {
    if (url.isEmpty) return true; // Optional field
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

  // NEW: Show popup for primary muscle percentage
  Future<int?> _showPercentDialog() async {
    final dialogKey = GlobalKey<FormState>();
    String input = '80';

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
              initialValue: '80',
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Percentage (1-99)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) {
                final p = int.tryParse(val ?? '');
                if (p == null || p < 1 || p > 99)
                  return 'Enter a value between 1 and 99';
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

    // Validate video URL
    if (videoUrl.isNotEmpty && !_isValidVideoUrl(videoUrl)) {
      setState(() {
        _videoUrlError =
            'Please enter a valid video URL (YouTube, Vimeo, .mp4, etc.)';
      });
      return;
    } else {
      setState(() => _videoUrlError = null);
    }

    _formKey.currentState!.save();
    setState(() => isLoading = true);

    final imageUrl = await _uploadImage();

    // NEW: Build muscles list and distribution list
    List<String> muscles = [];
    List<int> distribution = [];

    if (primaryMuscle != null && primaryMuscle != 'None') {
      muscles.add(primaryMuscle!);
      distribution
          .add(primaryPercent ?? 80); // Fallback, though dialog enforces
    }
    if (secondaryMuscle != null && secondaryMuscle != 'None') {
      muscles.add(secondaryMuscle!);
      distribution.add(100 - distribution[0]);
    } else if (muscles.isNotEmpty) {
      // If no secondary, set primary to 100% for full coverage
      distribution[0] = 100;
    }

    // UPDATED: Save equipment as list of IDs
    List<String> equipmentIds = [];
    if (selectedEquipmentName != null && selectedEquipmentName != 'None') {
      selectedEquipmentId = equipmentNameToId[selectedEquipmentName];
      if (selectedEquipmentId != null) {
        equipmentIds.add(selectedEquipmentId!);
      }
    }

    final customExercise = {
      'name': name.trim(),
      'type': type,
      'muscles': muscles,
      'muscleDistribution': distribution,
      'equipment': equipmentIds,
      'importance': importance,
      'relatedExercises': relatedExercises.where((e) => e != 'None').toList(),
      'instructions': instructions.trim(),
      'videoUrl': videoUrl.trim(),
      'imageUrl': imageUrl,
      'userId': user!.uid,
      'isPublic': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('exercises_custom')
          .add(customExercise);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom exercise added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving exercise: $e'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text(
          "Add Custom Exercise",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                    // Image Picker
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
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _image == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Colors.orange, size: 40),
                                    Text(
                                      "Add Image",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Name",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (val) =>
                          val?.trim().isEmpty == true ? 'Required' : null,
                      onSaved: (val) => name = val!.trim(),
                    ),
                    const SizedBox(height: 16),

                    // Type
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: "Type",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: [
                        'Weights',
                        'Cardio',
                        'Bodyweight'
                      ] // Example types, adjust as needed
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => type = val!),
                    ),
                    const SizedBox(height: 16),

                    // Primary Muscle — NEW: onChanged with popup
                    DropdownButtonFormField<String>(
                      value: primaryMuscle,
                      decoration: InputDecoration(
                        labelText: "Primary Muscle",
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
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) async {
                        setState(() => primaryMuscle = val);
                        if (val == null || val == 'None') return;
                        final percent = await _showPercentDialog();
                        if (percent == null) {
                          setState(() => primaryMuscle = null);
                        } else {
                          setState(() => primaryPercent = percent);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Secondary Muscle — NEW: onChanged with auto-calc
                    DropdownButtonFormField<String>(
                      value: secondaryMuscle,
                      hint: const Text("Secondary Muscle",
                          style: TextStyle(color: Colors.white70)),
                      decoration: InputDecoration(
                        labelText: "Secondary Muscle",
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
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) {
                        if (val == null || val == 'None') {
                          setState(() {
                            secondaryMuscle = null;
                            secondaryPercent = null;
                          });
                          return;
                        }
                        if (primaryMuscle == null ||
                            primaryMuscle == 'None' ||
                            primaryPercent == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please select and set percentage for primary muscle first.')),
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

                    // Equipment — UPDATED: onChanged sets name and ID
                    DropdownButtonFormField<String>(
                      value: selectedEquipmentName,
                      hint: const Text("Equipment",
                          style: TextStyle(color: Colors.white70)),
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
                      decoration: InputDecoration(
                        labelText: "Importance",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      decoration: InputDecoration(
                        labelText: "Related Exercises",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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

                    // Video URL with validation
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Video URL (optional)",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorText: _videoUrlError,
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        setState(() {
                          videoUrl = val;
                          _videoUrlError = null; // Clear on typing
                        });
                      },
                      onSaved: (val) => videoUrl = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Add instructions here",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      onSaved: (val) => instructions = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
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
                          : const Text(
                              "+ Add",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
