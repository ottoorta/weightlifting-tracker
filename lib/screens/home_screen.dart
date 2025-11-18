// lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/workout_card.dart';
import 'search_exercises.dart';
import 'search_equipments.dart';
import '../widgets/this_week_records.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!docSnap.exists) {
        setState(() {
          _currentGym = 'Home Gym';
          _currentCoach = 'No Coach';
        });
        return;
      }

      final data = docSnap.data()!;

      // SAFELY GET GYM NAME
      final gymCandidates = [
        data['gymName'],
        data['gym_name'],
        data['gym'],
      ].where((e) => e is String && e.trim().isNotEmpty);

      setState(() {
        _currentGym =
            gymCandidates.isNotEmpty ? gymCandidates.first : 'Home Gym';

        // SAFELY GET COACH
        final coachCandidates = [
          data['selectedCoach'],
          data['coach'],
          data['selected_coach'],
        ].where((e) => e is String && e.trim().isNotEmpty);

        final coachCode =
            coachCandidates.isNotEmpty ? coachCandidates.first : null;

        _currentCoach = coachCode == 'auto'
            ? 'Auto Coach'
            : coachCode == 'ai'
                ? 'AI Coach'
                : coachCode == 'pro'
                    ? 'Pro Coach'
                    : 'No Coach';
      });
    } catch (e) {
      debugPrint('Home load error: $e');
      setState(() {
        _currentGym = 'Home Gym';
        _currentCoach = 'No Coach';
      });
    }
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
                .set({'gymName': gym}, SetOptions(merge: true));
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
                .set({'selectedCoach': code}, SetOptions(merge: true));

            setState(() => _currentCoach = coach);
            Navigator.pop(context);
          },
        ),
      );

  void _onNavTap(int index) {
    if (index == 1) {
      // <-- SEARCH ICON (índice 1)
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Container(
          height: 240,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 10),
                child: Text(
                  "Search",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.orange),
                title: const Text("Search Exercises",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchExercisesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.build, color: Colors.orange),
                title: const Text("Search Equipment",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SearchEquipmentsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (index == 4) {
      Navigator.pushNamed(context, '/profile_settings');
      return;
    }

    // Otros íconos: navegan normalmente
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
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // ← THIS FIXES THE OVERFLOW!
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

              // WORKOUT CARD
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: WorkoutCard(),
              ),

              const SizedBox(
                  height:
                      10), //espacio entre widget your next workout y this weeks records
              const ThisWeekRecords(),
// Mantén un poco de espacio para el bottom nav
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart), label: 'Stats'),
            BottomNavigationBarItem(
                icon: Icon(Icons.message), label: 'Messages'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }
}

// REUSABLE DROPDOWN + PICKER stay EXACTLY the same as before
class _DropdownButton extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DropdownButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
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
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
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
