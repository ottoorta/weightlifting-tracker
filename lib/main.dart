// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/confirmation_code_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/first_user_inputs_screen.dart';
import 'screens/your_gym_screen.dart';
import 'screens/forging_exp_screen.dart';
import 'screens/set_new_password_screen.dart';
import 'screens/search_menu_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/profile_screen.dart';
import 'package:iron_coach/screens/workout_main.dart';

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
      home: const AuthWrapper(), // THIS IS YOUR START
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/first_inputs': (context) => const FirstUserInputsScreen(),
        '/your_gym': (context) => const YourGymScreen(),
        '/forging_exp': (context) => const ForgingExpScreen(),
        '/confirm': (context) => ConfirmationCodeScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/check_email_reset': (context) => ConfirmationCodeScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
              resetMode: true,
            ),
        '/set_new_password': (context) => SetNewPasswordScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/home': (context) => const HomeScreen(),
        '/search_menu': (context) => const SearchMenuScreen(),
        '/stats': (context) => const StatsScreen(),
        '/messages': (context) => const MessagesScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/workout_main': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return WorkoutMainScreen(
            workout: args['workout'] as Map<String, dynamic>,
            exercises: args['exercises'] as List<Map<String, dynamic>>,
          );
        },
        '/subscriptions': (context) => const Scaffold(
              body: Center(
                child: Text(
                  "Subscribe for UNLIMITED Auto Coach!",
                  style: TextStyle(fontSize: 24, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      },
    );
  }
}

// AUTH WRAPPER — LOGGED IN → HOME, LOGGED OUT → SIGN IN
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body:
                Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }
        return snapshot.hasData ? const HomeScreen() : const SignInScreen();
      },
    );
  }
}
