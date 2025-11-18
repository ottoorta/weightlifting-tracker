// lib/screens/profile_settings.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  late Map<String, dynamic> userData;
  bool _isLoading = true;
  File? _newImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      userData = doc.data() ?? {};
      _isLoading = false;
    });
  }

  Future<void> _updateField(String field, dynamic value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({field: value}, SetOptions(merge: true));
    setState(() => userData[field] = value);
  }

  Future<void> _pickAndUploadImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _newImage = File(picked.path));

    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_pics')
        .child('${user.uid}.jpg');
    await ref.putFile(_newImage!);
    final url = await ref.getDownloadURL();

    await _updateField('photoURL', url);
    setState(() => _newImage = null);
  }

  Future<void> _showDatePicker() async {
    final currentDate = userData['birthDate'] != null
        ? DateTime.tryParse(userData['birthDate']) ?? DateTime.now()
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white),
          dialogBackgroundColor: const Color(0xFF1C1C1E),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted = DateFormat('dd MMMM yyyy').format(picked);
      await _updateField('birthDate', picked.toIso8601String());
      await _updateField('birthDateDisplay', formatted);
    }
  }

  String _formatWeightUnit(String? raw) {
    if (raw == null) return 'Kilograms - Kg';
    final lower = raw.toString().trim().toLowerCase();
    if (lower.contains('kg') || lower.contains('kilogram'))
      return 'Kilograms - Kg';
    if (lower.contains('lbs') ||
        lower.contains('pound') ||
        lower.contains('lb')) return 'Pounds - Lbs';
    return 'Kilograms - Kg';
  }

  String _formatMeasureUnit(String? raw) {
    if (raw == null) return 'Centimeters - Cm';
    final lower = raw.toString().trim().toLowerCase();
    if (lower.contains('cm') || lower.contains('centimeter'))
      return 'Centimeters - Cm';
    if (lower.contains('ft') ||
        lower.contains('feet') ||
        lower.contains('foot')) return 'Feet - Ft';
    return 'Centimeters - Cm';
  }

  String _formatDistanceUnit(String? raw) {
    if (raw == null) return 'Kilometers - Km';
    final lower = raw.toString().trim().toLowerCase();
    if (lower.contains('km') || lower.contains('kilometer'))
      return 'Kilometers - Km';
    if (lower.contains('mi') || lower.contains('mile')) return 'Miles - Mi';
    return 'Kilometers - Km';
  }

  String _shortWeightUnit(String display) =>
      display.contains('Pounds') ? 'LBS' : 'KG';
  String _shortMeasureUnit(String display) =>
      display.contains('Feet') ? 'FT' : 'CM';
  String _shortDistanceUnit(String display) =>
      display.contains('Miles') ? 'MI' : 'KM';

  void _showEditDialog({
    required String title,
    required String currentValue,
    required String field,
    TextInputType? keyboardType,
    List<String>? options,
    bool isDate = false,
  }) {
    if (isDate) {
      _showDatePicker();
      return;
    }
    final controller = TextEditingController(text: currentValue);
    String? selected = options != null ? currentValue : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: options != null
            ? DropdownButtonFormField<String>(
                value: selected,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF2C2C2E),
                    border: OutlineInputBorder(borderSide: BorderSide.none)),
                items: options
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => selected = val,
              )
            : TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF2C2C2E),
                    border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () {
              String? value;
              if (options != null) {
                value = selected;
                if (field == 'weightUnit') value = _shortWeightUnit(selected!);
                if (field == 'measureUnit')
                  value = _shortMeasureUnit(selected!);
                if (field == 'distanceUnit')
                  value = _shortDistanceUnit(selected!);
              } else {
                value = controller.text.trim();
              }
              if (value != null &&
                  value != currentValue &&
                  value.toString().isNotEmpty) {
                _updateField(field, value);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTile(String label, String value, String field,
      {TextInputType? keyboardType,
      List<String>? options,
      bool isDate = false,
      bool editable = true}) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4), // REDUCIDO
      leading: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      title: Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
      trailing: editable
          ? const Icon(Icons.edit, color: Colors.orange, size: 20)
          : null,
      onTap: editable
          ? () => _showEditDialog(
              title: label,
              currentValue: value,
              field: field,
              keyboardType: keyboardType,
              options: options,
              isDate: isDate)
          : null,
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _InfoDialog(title: "Terms and Conditions", content: _termsText),
    );
  }

  void _showPrivacy() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _InfoDialog(title: "Privacy Policy", content: _privacyText),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(child: CircularProgressIndicator(color: Colors.orange)));
    }

    final photoURL = userData['photoURL'] as String? ?? '';
    final displayName = userData['displayName'] as String? ??
        user.email?.split('@').first ??
        'User';

    String birthDateDisplay = 'Not set';
    if (userData['birthDateDisplay'] != null) {
      birthDateDisplay = userData['birthDateDisplay'];
    } else if (userData['birthDate'] != null) {
      try {
        final date = DateTime.parse(userData['birthDate']);
        birthDateDisplay = DateFormat('dd MMMM yyyy').format(date);
      } catch (e) {
        birthDateDisplay = userData['birthDate'];
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
            onPressed: () => Navigator.pop(context)),
        title: const Text("Profile Settings",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _newImage != null
                        ? FileImage(_newImage!)
                        : (photoURL.isNotEmpty ? NetworkImage(photoURL) : null)
                            as ImageProvider?,
                    child: _newImage == null && photoURL.isEmpty
                        ? const Icon(Icons.person,
                            size: 60, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => _showEditDialog(
                        title: "Edit Name",
                        currentValue: displayName,
                        field: 'displayName'),
                    child: const Text("Tap to edit name",
                        style: TextStyle(color: Colors.orange, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white24, height: 1),

            _buildEditTile("Gender", userData['gender'] ?? 'Not set', 'gender',
                options: ['Male', 'Female', 'Other']),
            _buildEditTile("Date of Birth", birthDateDisplay, 'birthDate',
                isDate: true),
            _buildEditTile(
                "Weight",
                "${userData['weight'] ?? ''} ${userData['weightUnit'] == 'LBS' ? 'Lbs' : 'Kg'}",
                'weight',
                keyboardType: TextInputType.number),
            _buildEditTile(
                "Height", userData['height']?.toString() ?? 'Not set', 'height',
                keyboardType: TextInputType.number),
            _buildEditTile("Unit of Weights",
                _formatWeightUnit(userData['weightUnit']), 'weightUnit',
                options: ['Kilograms - Kg', 'Pounds - Lbs']),
            _buildEditTile("Unit of Measure",
                _formatMeasureUnit(userData['measureUnit']), 'measureUnit',
                options: ['Centimeters - Cm', 'Feet - Ft']),
            _buildEditTile("Unit of Distance",
                _formatDistanceUnit(userData['distanceUnit']), 'distanceUnit',
                options: ['Kilometers - Km', 'Miles - Mi']),
            _buildEditTile("Profile Type",
                userData['profileType'] ?? 'Hypertrophy', 'profileType',
                options: [
                  'Hypertrophy',
                  'Strength',
                  'Lose Weight',
                  'Gain Weight',
                  'Lean'
                ]),
            _buildEditTile("Email", user.email!, 'email',
                editable: false), // NO EDITABLE
            _buildEditTile(
                "Language", userData['language'] ?? 'English (EN)', 'language',
                options: ['English (EN)', 'Español (ES)']),
            _buildEditTile("Subscription", userData['subscription'] ?? 'Basic',
                'subscription',
                options: ['Basic', 'Pro', 'Premium']),

            const Divider(color: Colors.white24, height: 40),

            ListTile(
                leading: const Icon(Icons.description, color: Colors.orange),
                title: const Text("Terms and Conditions",
                    style: TextStyle(color: Colors.white)),
                onTap: _showTerms),
            ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.orange),
                title: const Text("Privacy Policy",
                    style: TextStyle(color: Colors.white)),
                onTap: _showPrivacy),
            ListTile(
                leading: const Icon(Icons.mail, color: Colors.orange),
                title: const Text("Contact Us",
                    style: TextStyle(color: Colors.white)),
                onTap: () {}),

            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted)
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/splash', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 56),
                    shape: const StadiumBorder()),
                child: const Text("Log Out",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// POPUP REUTILIZABLE
class _InfoDialog extends StatelessWidget {
  final String title;
  final String content;
  const _InfoDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: SingleChildScrollView(
                child: Text(content,
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TEXTOS REALES
const String _termsText = """
IRON COACH - TERMS AND CONDITIONS

1. Acceptance of Terms
By using Iron Coach, you agree to these Terms and Conditions.

2. User Account
You are responsible for maintaining the confidentiality of your account.

3. Content
You retain ownership of your custom exercises and equipment.

4. Subscription
Basic features are free. Premium features require payment.

5. Termination
We may terminate or suspend your account at any time.

6. Changes
We reserve the right to modify these terms at any time.

Last updated: November 2025
""";

const String _privacyText = """
IRON COACH - PRIVACY POLICY

1. Information We Collect
- Account information (email, name, profile data)
- Workout and exercise history
- Device information

2. How We Use Your Information
- To provide and improve the app
- To personalize your experience
- To send important notifications

3. Data Storage
Your data is stored securely in Firebase.

4. Data Sharing
We do not sell your personal information.

5. Your Rights
You can delete your account and all data at any time.

6. Contact
For privacy questions: support@ironcoach.app

Last updated: November 2025
""";
