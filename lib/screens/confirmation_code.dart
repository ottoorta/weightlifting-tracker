import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'first_user_inputs.dart';

class ConfirmationCodeScreen extends StatefulWidget {
  final String uid;
  const ConfirmationCodeScreen({super.key, required this.uid});
  @override
  State<ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

class _ConfirmationCodeScreenState extends State<ConfirmationCodeScreen> {
  final _code = TextEditingController();
  String _error = '';

  Future<void> _verify() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    if (_code.text == doc['verificationCode']) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'verified': true});
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const FirstUserInputs()));
    } else {
      setState(() => _error = 'Invalid code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Enter 4-digit code from email'),
          TextField(controller: _code, keyboardType: TextInputType.number),
          ElevatedButton(onPressed: _verify, child: const Text('Verify')),
          if (_error.isNotEmpty) Text(_error),
        ]),
      ),
    );
  }
}
