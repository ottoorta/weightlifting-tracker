// lib/screens/forging_exp_screen.dart
import 'package:flutter/material.dart';

class ForgingExpScreen extends StatelessWidget {
  const ForgingExpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset('assets/images/iron_background.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity),
          Container(color: Colors.black.withOpacity(0.7)),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('FORGING YOUR EXPERIENCE',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
                SizedBox(height: 20),
                CircularProgressIndicator(color: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
