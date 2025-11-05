import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'first_user_inputs.dart';

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

  Future<void> _login() async {
    try {
      setState(() => _error = '');
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      await _saveRemember();
      await _checkFirstInputs(cred.user!.uid);
    } catch (e) {
      setState(() => _error = 'Check wrong email or password');
    }
  }

  Future<void> _google() async {
    try {
      // Clear previous session
      await GoogleSignIn().signOut();

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login cancelled')),
          );
        }
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // THIS LINE WAS MISSING — NOW IT NAVIGATES
      await _checkFirstInputs(userCred.user!.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  Future<void> _facebook() async => await _socialLogin(() async {
        final r = await FacebookAuth.instance.login();
        return FacebookAuthProvider.credential(r.accessToken!.token);
      });

  Future<void> _socialLogin(Future<AuthCredential> Function() getCred) async {
    final cred = await getCred();
    final user = await FirebaseAuth.instance.signInWithCredential(cred);
    await _checkFirstInputs(user.user!.uid);
  }

  Future<void> _saveRemember() async {
    final p = await SharedPreferences.getInstance();
    p.setBool('remember_me', _remember);
  }

  Future<void> _checkFirstInputs(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => doc.exists && doc['gender'] != null
            ? const HomeScreen()
            : const FirstUserInputs(),
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
                  const Text('Sign in',
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const Text('Sign in to your account via email',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: Colors.white)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: 'Enter your password',
                          filled: true,
                          fillColor: Colors.white)),
                  if (_error.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error,
                            style: const TextStyle(color: Colors.orange))),
                  Row(children: [
                    Checkbox(
                        value: _remember,
                        onChanged: (v) => setState(() => _remember = v!)),
                    const Text('Remember me',
                        style: TextStyle(color: Colors.orange)),
                    const Spacer(),
                    GestureDetector(
                        onTap: () {},
                        child: const Text('Forgot password?',
                            style: TextStyle(color: Colors.orange))),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder()),
                    child: const Text('Sign in →',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                  const Center(
                      child: Text('Sign in with social media',
                          style: TextStyle(color: Colors.white))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                      onPressed: _google,
                      icon: const Icon(Icons.g_mobiledata, color: Colors.red),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                      onPressed: _facebook,
                      icon: const Icon(Icons.facebook, color: Colors.blue),
                      label: const Text('Sign in with Facebook'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black)),
                  const SizedBox(height: 32),
                  Center(
                      child: GestureDetector(
                          onTap: () {},
                          child: const Text('Not a member Create a new account',
                              style: TextStyle(color: Colors.orange)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
