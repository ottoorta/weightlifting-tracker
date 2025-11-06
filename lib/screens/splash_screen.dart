// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3)); // Feel the power
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final next = user != null ? '/home' : '/signin';

    Navigator.pushReplacementNamed(context, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
          Container(color: const Color(0x80000000)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const Text('IRON COACH',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3)),
                const SizedBox(height: 12),
                const Text('Bring the best out of you!',
                    style: TextStyle(fontSize: 20, color: Colors.white70)),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  /*child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/signin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Sign in',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),*/
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
