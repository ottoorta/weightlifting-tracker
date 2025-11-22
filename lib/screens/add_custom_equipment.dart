// lib/screens/add_custom_equipment.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddCustomEquipmentScreen extends StatefulWidget {
  const AddCustomEquipmentScreen({super.key});

  @override
  State<AddCustomEquipmentScreen> createState() =>
      _AddCustomEquipmentScreenState();
}

class _AddCustomEquipmentScreenState extends State<AddCustomEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();

  String name = '';
  String? primaryMuscle;
  String? secondaryMuscle;
  String instructions = '';
  File? _image;

  List<String> muscleList = ['None'];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMuscles();
  }

  Future<void> _loadMuscles() async {
    final snap = await FirebaseFirestore.instance.collection('muscles').get();
    final names = snap.docs.map((doc) => doc['name'] as String).toList()
      ..sort();
    setState(() => muscleList = ['None', ...names]);
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null || user == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('custom_equipment')
        .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_image!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    _formKey.currentState!.save();
    setState(() => isLoading = true);

    final imageUrl = await _uploadImage();

    // Construir muscleGroups como string concatenado
    List<String> selectedMuscles = [];
    if (primaryMuscle != null && primaryMuscle != 'None') {
      selectedMuscles.add(primaryMuscle!);
    }
    if (secondaryMuscle != null && secondaryMuscle != 'None') {
      selectedMuscles.add(secondaryMuscle!);
    }
    final muscleGroups =
        selectedMuscles.isEmpty ? 'None' : selectedMuscles.join(', ');

    final customEquipment = {
      'name': name.trim(),
      'imageUrl': imageUrl,
      'muscleGroups': muscleGroups,
      'instructions': instructions.trim(),
      'userId': user!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('equipment_custom')
          .add(customEquipment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom equipment added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Regresa y recarga la lista
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
        title: const Text(
          "Add Custom Equipment",
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
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: _image == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Colors.orange, size: 40),
                                    SizedBox(height: 8),
                                    Text("Add Image",
                                        style:
                                            TextStyle(color: Colors.white70)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

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

                    // Primary Muscle
                    DropdownButtonFormField<String>(
                      value: primaryMuscle,
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

                    // Secondary Muscle
                    DropdownButtonFormField<String>(
                      value: secondaryMuscle,
                      decoration: InputDecoration(
                        labelText: "Secondary Muscle (optional)",
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

                    // Instructions
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
                      onSaved: (val) => instructions = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 40),

                    // Add Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveEquipment,
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
                                  color: Colors.white, strokeWidth: 2))
                          : const Text("+ Add",
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
