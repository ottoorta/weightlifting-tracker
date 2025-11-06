// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/first_user_inputs_screen.dart';
import 'screens/your_gym_screen.dart'; // If adding the stub
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/confirmation_code_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/forging_exp_screen.dart';
import 'screens/set_new_password_screen.dart';

import 'screens/search_menu_screen.dart'; // create empty file
import 'screens/stats_screen.dart'; // create empty file
import 'screens/messages_screen.dart'; // create empty file
import 'screens/profile_screen.dart'; // create empty file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const IronCoachApp());
}

class IronCoachApp extends StatelessWidget {
  const IronCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRON COACH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: Colors.transparent,
      ),

      // ALL ROUTES — NAMED & READY
      routes: {
        '/': (context) => const SplashScreen(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/first_inputs': (context) => const FirstUserInputsScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/your_gym': (context) => const YourGymScreen(),
        '/forging_exp': (context) => const ForgingExpScreen(),
        '/confirm': (context) => ConfirmationCodeScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/check_email_reset': (context) => ConfirmationCodeScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
              resetMode: true, // Pass via args if needed; handle in constructor
            ),
        '/set_new_password': (context) => SetNewPasswordScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/home': (context) => const HomeScreen(),
        '/search_menu': (context) =>
            const Scaffold(body: Center(child: Text('Search Menu'))),
        '/stats': (context) =>
            const Scaffold(body: Center(child: Text('Stats'))),
        '/messages': (context) =>
            const Scaffold(body: Center(child: Text('Messages'))),
        '/profile': (context) =>
            const Scaffold(body: Center(child: Text('Profile'))),
      },

      // DEFAULT: Splash
      initialRoute: '/',
    );
  }
}
