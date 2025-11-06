// lib/screens/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'sign_in_screen.dart';
import 'confirmation_code_screen.dart'; // <-- now receives uid + email

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
  bool _isLoading = false;

  // -----------------------------------------------------------------
  // 1. Generate a REAL random 4-digit code
  // -----------------------------------------------------------------
  String _generateCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  // -----------------------------------------------------------------
  // 2. Sign-up + Firestore + navigate
  // -----------------------------------------------------------------
  Future<void> _signUp() async {
    if (_password.text.trim() != _confirmPassword.text.trim()) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (!_agree) {
      setState(() => _error = 'Please agree to the Terms');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 1. Create Auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      final uid = cred.user!.uid;
      final code = _generateCode();

      // 2. Save user + verification code
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'verificationCode': code,
        'verificationTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      // 3. (Optional) Trigger Cloud Function to send email
      // await FirebaseFunctions.instance
      //     .httpsCallable('sendVerificationEmail')
      //     .call({'email': _email.text.trim(), 'code': code});

      // 4. Go straight to Confirmation Code
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/confirm',
        arguments: _email.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Sign-up failed');
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -----------------------------------------------------------------
  // 3. Terms dialog
  // -----------------------------------------------------------------
  void _showTerms() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text('''[Paste full Terms & Privacy Policy here]'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Image.asset(
            'assets/images/splash_bg.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // Dark overlay
          Container(color: const Color(0x80000000)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Back arrow (matches every other screen)
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Create an account to get started',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),

                  const SizedBox(height: 32),

                  // Name
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Create a password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Confirm Password
                  TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Confirm password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Terms checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _agree,
                        activeColor: Colors.orange,
                        onChanged: (v) => setState(() => _agree = v!),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showTerms,
                          child: const Text(
                            "I’ve read and agree with the Terms and Conditions "
                            "and the Privacy Policy",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Error message
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Sign Up button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),

                  const SizedBox(height: 32),

                  // Already a member?
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      ),
                      child: const Text(
                        'Already a member? Sign In',
                        style: TextStyle(color: Colors.orange),
                      ),
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
