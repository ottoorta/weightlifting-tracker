// lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _currentGym = 'Loading...';
  String _currentCoach = 'No Coach';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return;

    setState(() {
      _currentGym = doc['gymName'] ?? 'Home Gym';
      final coach = doc['selectedCoach'] ?? 'No Coach';
      _currentCoach = coach == 'auto'
          ? 'Auto Coach'
          : coach == 'ai'
              ? 'AI Coach'
              : coach == 'pro'
                  ? 'Pro Coach'
                  : 'No Coach';
    });
  }

  void _showGymPicker() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _GymCoachPicker(
          title: 'Working out at',
          options: ['Home Gym', 'Fit4All Gym', 'Planet Fitness'],
          current: _currentGym,
          onSelect: (gym) async {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'gymName': gym});
            setState(() => _currentGym = gym);
            Navigator.pop(context);
          },
        ),
      );

  void _showCoachPicker() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _GymCoachPicker(
          title: 'Select your Coach',
          options: ['No Coach', 'Auto Coach', 'AI Coach', 'Pro Coach'],
          current: _currentCoach,
          onSelect: (coach) async {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final code = coach == 'Auto Coach'
                ? 'auto'
                : coach == 'AI Coach'
                    ? 'ai'
                    : coach == 'Pro Coach'
                        ? 'pro'
                        : null;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'selectedCoach': code});
            setState(() => _currentCoach = coach);
            Navigator.pop(context);
          },
        ),
      );

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/home', '/search_menu', '/stats', '/messages', '/profile'];
    Navigator.pushNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.white),
        actions: const [
          Icon(Icons.notifications, color: Colors.white),
          SizedBox(width: 16)
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TOP DROPDOWNS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _DropdownButton(
                      label: 'Working out at:',
                      value: _currentGym,
                      onTap: _showGymPicker,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownButton(
                      label: 'Select your Coach:',
                      value: _currentCoach,
                      onTap: _showCoachPicker,
                    ),
                  ),
                ],
              ),
            ),

            // HERO CARD (Coming next)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Your Next Workout\nCOMING SOON',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(),

            // BOTTOM NAV
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onNavTap,
                backgroundColor: Colors.transparent,
                selectedItemColor: Colors.orange,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.search), label: 'Search'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart), label: 'Stats'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.message), label: 'Messages'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person), label: 'Account'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// REUSABLE DROPDOWN
class _DropdownButton extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DropdownButton(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.orange, fontSize: 12)),
            Row(
              children: [
                Expanded(
                    child: Text(value,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// MODAL PICKER
class _GymCoachPicker extends StatelessWidget {
  final String title, current;
  final List<String> options;
  final Function(String) onSelect;

  const _GymCoachPicker({
    required this.title,
    required this.options,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          ...options.map((opt) => ListTile(
                title: Text(opt, style: const TextStyle(color: Colors.white)),
                trailing: opt == current
                    ? const Icon(Icons.check, color: Colors.orange)
                    : null,
                onTap: () => onSelect(opt),
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
