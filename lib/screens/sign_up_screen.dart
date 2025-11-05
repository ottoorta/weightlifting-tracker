import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_in_screen.dart'; // For back navigation
import 'confirmation_code.dart'; // Stub for screen 08

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _agree = false;
  String _error = '';

  Future<void> _signUp() async {
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (!_agree) {
      setState(() => _error = 'Please agree to terms');
      return;
    }

    setState(() => _error = '');
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _email.text.trim(),
      password: _password.text.trim(),
    );

    final uid = cred.user!.uid;
    debugPrint('User created: $uid → Saving to Firestore...');
    final code =
        (1000 + DateTime.now().millisecond % 9000).toString(); // 4-digit code

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'verificationCode': code,
      'verificationTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Assume email sent with code (we can add Cloud Function later)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConfirmationCodeScreen(uid: uid)),
    );

    //setState(() => _error = 'Sign up failed: $e');
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const Text('Full terms here...'), // Add real text later
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset('assets/images/splash_bg.jpg',
              fit: BoxFit.cover, height: double.infinity),
          Container(color: const Color(0x80000000)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Text('Sign up',
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const Text('Create an account to get started',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          hintText: 'Enter your name',
                          filled: true,
                          fillColor: Colors.white)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: Colors.white)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: 'Create a password',
                          filled: true,
                          fillColor: Colors.white)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: 'Confirm password',
                          filled: true,
                          fillColor: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v!)),
                      Expanded(
                          child: GestureDetector(
                              onTap: _showTerms,
                              child: const Text(
                                  'I’ve read and agree with the Terms and Conditions and the Privacy Policy',
                                  style: TextStyle(color: Colors.orange)))),
                    ],
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error,
                            style: const TextStyle(color: Colors.orange))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder()),
                    child: const Text('Sign Up →',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignInScreen())),
                      child: const Text('Already a member? Sign In',
                          style: TextStyle(color: Colors.orange)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
