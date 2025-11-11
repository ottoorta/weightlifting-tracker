// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _autoNavigate();
  }

  Future<void> _autoNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final next = user != null ? '/home' : '/signin';
    Navigator.pushReplacementNamed(context, next);
  }

  void _showPowerOverlay() {
    if (_showOverlay) return;
    setState(() => _showOverlay = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Optional: Add your fire logo
              // Image.asset('assets/images/fire_iron.png', height: 100),
              // const SizedBox(height: 20),
              const Text(
                'IRON COACH',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bring the best out of you!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  final user = FirebaseAuth.instance.currentUser;
                  final next = user != null ? '/home' : '/signin';
                  Navigator.pushReplacementNamed(context, next);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'UNLEASH THE BEAST',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _showPowerOverlay, // TAP ANYWHERE = OVERLAY
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
            Container(color: const Color(0x80000000)), // Dark overlay
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  const Text(
                    'IRON COACH',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 4),
                          blurRadius: 10,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Forge the best out of you!',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const Spacer(flex: 2),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Tap anywhere to begin...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
