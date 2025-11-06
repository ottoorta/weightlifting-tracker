// lib/screens/set_new_password_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SetNewPasswordScreen extends StatefulWidget {
  final String email;
  const SetNewPasswordScreen({super.key, required this.email});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sendMagicLink();
  }

  Future<void> _sendMagicLink() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: const Text(
            'Magic link sent! Check your email.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/signin', (r) => false);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // EPIC IRON WARRIOR BACKGROUND
          Image.asset(
            'assets/images/splash_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.7)),

          SafeArea(
            child: Column(
              children: [
                // TOP-LEFT BACK ARROW
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // PERFECTLY CENTERED CONTENT
                Column(
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text(
                      'Check Your Email',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We sent a password reset link to',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tap the link in your email to set a new password.\nYou\'ll be signed in automatically.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const Spacer(flex: 3),

                // ORANGE BANNER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.orange,
                  child: const Column(
                    children: [
                      Text(
                        'Check your email!',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'We sent you a magic link to reset your password.',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // LOADING OVERLAY
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}
