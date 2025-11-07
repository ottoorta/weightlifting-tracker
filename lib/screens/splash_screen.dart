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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/splash_bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text(
                "IRON COACH",
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 12),
              const Text(
                "Bring the best out of you!",
                style: TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                /*
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("Sign in",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),*/
              ),
            ],
          ),
        ),
      ),
    );
  }
}
