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
  String? equipment;
  String importance = 'Medium';
  List<String> relatedExercises = [];
  String instructions = '';
  String videoUrl = '';
  File? _image;

  List<String> muscleList = ['None'];
  List<String> equipmentList = ['None'];
  List<String> exerciseNames = ['None'];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMuscles(),
      _loadEquipment(),
      _loadExerciseNames(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> _loadMuscles() async {
    final snap = await FirebaseFirestore.instance.collection('muscles').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() => muscleList = ['None', ...names]..sort());
  }

  Future<void> _loadEquipment() async {
    final snap = await FirebaseFirestore.instance.collection('equipment').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList();
    setState(() => equipmentList = ['None', ...names]..sort());
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

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate() || user == null) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);

    final imageUrl = await _uploadImage();

    final customExercise = {
      'name': name,
      'type': type,
      'primaryMuscle': primaryMuscle == 'None' ? null : primaryMuscle,
      'secondaryMuscle': secondaryMuscle == 'None' ? null : secondaryMuscle,
      'equipment': equipment == 'None' ? [] : [equipment],
      'importance': importance,
      'relatedExercises': relatedExercises.where((e) => e != 'None').toList(),
      'instructions': instructions,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'userId': user!.uid,
      'isPublic': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('exercises_custom')
        .add(customExercise);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Custom exercise added!'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
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
        title: const Text("Add Custom Exercise",
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
                                : null,
                          ),
                          child: _image == null
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
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Name",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (val) =>
                          val?.isEmpty == true ? 'Required' : null,
                      onSaved: (val) => name = val!,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: "Type",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: [
                        'Weights',
                        'Bodyweight',
                        'Cardio',
                        'Time',
                        'Distance'
                      ]
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => type = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: primaryMuscle,
                      hint: const Text("Primary Muscle",
                          style: TextStyle(color: Colors.white70)),
                      decoration: InputDecoration(
                        labelText: "Primary Muscle",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: muscleList
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => primaryMuscle = val),
                    ),
                    const SizedBox(height: 16),
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
                            borderSide: BorderSide.none),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: muscleList
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => secondaryMuscle = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: equipment,
                      hint: const Text("Equipment",
                          style: TextStyle(color: Colors.white70)),
                      decoration: InputDecoration(
                        labelText: "Equipment",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      dropdownColor: const Color(0xFF1C1C1E),
                      items: equipmentList
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setState(() => equipment = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: importance,
                      decoration: InputDecoration(
                        labelText: "Importance",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
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
                    DropdownButtonFormField<String>(
                      hint: const Text("Related Exercises",
                          style: TextStyle(color: Colors.white70)),
                      decoration: InputDecoration(
                        labelText: "Related Exercises",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
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
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Video URL (optional)",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onSaved: (val) => videoUrl = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Add instructions here",
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      onSaved: (val) => instructions = val ?? '',
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveExercise,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 56),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text("+ Add",
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
