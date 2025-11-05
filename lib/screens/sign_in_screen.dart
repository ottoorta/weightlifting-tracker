// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = false;
  String _error = '';
  bool _loading = false;

  // Save "Remember me"
  Future<void> _saveRemember() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _remember);
  }

  // LOGIN → GO HOME (no first inputs check!)
  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      setState(() => _error = '');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      await _saveRemember();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      }
    } catch (e) {
      setState(() => _error = 'Check wrong email or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // GOOGLE
  Future<void> _google() async {
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      }
    } catch (e) {
      _showSnack('Google login failed');
    }
  }

  // FACEBOOK
  Future<void> _facebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.accessToken == null) return;

      final credential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      }
    } catch (e) {
      _showSnack('Facebook login failed');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
                  const Text('Sign in',
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const Text('Sign in to your account via email',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),

                  // Email
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'Enter your email',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      hintText: 'Enter your password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  // Error
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error,
                          style: const TextStyle(color: Colors.orange)),
                    ),

                  // Remember + Forgot
                  Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        activeColor: Colors.orange,
                        onChanged: (v) => setState(() => _remember = v!),
                      ),
                      const Text('Remember me',
                          style: TextStyle(color: Colors.orange)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/forgot'),
                        child: const Text('Forgot password?',
                            style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SIGN IN BUTTON
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Sign in',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 32),
                  const Center(
                    child: Text('Sign in with social media',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),

                  // Google
                  ElevatedButton.icon(
                    onPressed: _google,
                    icon: const Icon(Icons.g_mobiledata, color: Colors.red),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Facebook
                  ElevatedButton.icon(
                    onPressed: _facebook,
                    icon: const Icon(Icons.facebook, color: Colors.blue),
                    label: const Text('Sign in with Facebook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text('Not a member? Create a new account',
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
