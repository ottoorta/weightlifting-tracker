// lib/screens/confirmation_code_screen.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConfirmationCodeScreen extends StatefulWidget {
  final String email;
  final bool resetMode;
  const ConfirmationCodeScreen({
    super.key,
    required this.email,
    this.resetMode = false,
  });

  @override
  State<ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

class _ConfirmationCodeScreenState extends State<ConfirmationCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _showError = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length != 4) {
      setState(() => _showError = true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.resetMode) {
        // PASSWORD RESET MODE
        final tempDoc = await FirebaseFirestore.instance
            .collection('temp_reset_codes')
            .doc(widget.email)
            .get();

        if (!tempDoc.exists) {
          setState(() => _showError = true);
          return;
        }

        final data = tempDoc.data() as Map<String, dynamic>;
        final code = data['code'] as String?;
        final createdAt = data['createdAt'] as Timestamp?;
        final now = Timestamp.now();

// 1. Code wrong?
        if (code != enteredCode) {
          setState(() => _showError = true);
          return;
        }

// 2. Code expired? (older than 10 minutes)
        if (createdAt == null || now.seconds - createdAt.seconds > 600) {
          await tempDoc.reference.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code expired. Request a new one.')),
          );
          setState(() => _showError = true);
          return;
        }

        // Delete temp code
        await tempDoc.reference.delete();

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/set_new_password',
            arguments: widget.email,
          );
        }
      } else {
        // SIGN-UP VERIFICATION MODE
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!userDoc.exists || userDoc['verificationCode'] != enteredCode) {
          setState(() => _showError = true);
          return;
        }

        await userDoc.reference.update({
          'verified': true,
          'verificationCode': FieldValue.delete(),
        });

        final bool hasInputs = userDoc.data()?['gender'] != null;

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            hasInputs ? '/home' : '/first_inputs',
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      final newCode = (1000 + Random().nextInt(9000)).toString();

      if (widget.resetMode) {
        await FirebaseFirestore.instance
            .collection('temp_reset_codes')
            .doc(widget.email)
            .set({
          'code': newCode,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'verificationCode': newCode,
          'verificationTime': FieldValue.serverTimestamp(),
        });
      }

      for (var c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      setState(() => _showError = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New code sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resend failed: $e')),
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
          // EPIC BACKGROUND
          Image.asset(
            'assets/images/iron_background.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.60)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Arrow
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 40),

                  // Dynamic Title
                  Text(
                    widget.resetMode ? 'Check your Email' : 'Check your Email',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.resetMode
                        ? 'We sent a reset code to ${widget.email}\nEnter the 4 digit code mentioned in the email'
                        : 'We sent a confirmation code to ${widget.email}\nEnter the 4 digit code mentioned in the email',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),

                  // 4-Digit PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                        4,
                        (i) => SizedBox(
                              width: 64,
                              height: 64,
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (v) {
                                  if (v.isNotEmpty && i < 3) {
                                    _focusNodes[i + 1].requestFocus();
                                  } else if (v.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                  setState(() => _showError = false);
                                },
                              ),
                            )),
                  ),

                  if (_showError)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          'Wrong code, please verify and try again!',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Haven't got email yet? ",
                            style: TextStyle(color: Colors.white70)),
                        GestureDetector(
                          onTap: _isLoading ? null : _resendCode,
                          child: const Text(
                            'Resend Email',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
