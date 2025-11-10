// lib/screens/workout_exercise.dart
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkoutExerciseScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String workoutId;

  const WorkoutExerciseScreen({
    super.key,
    required this.exercise,
    required this.workoutId,
  });

  @override
  State<WorkoutExerciseScreen> createState() => _WorkoutExerciseScreenState();
}

class _WorkoutExerciseScreenState extends State<WorkoutExerciseScreen> {
  List<Map<String, dynamic>> sets = [];
  int totalReps = 0;
  double totalCalories = 0.0;
  double totalVolume = 0.0;
  double oneRepMax = 0.0;
  double maxWeight = 0.0;
  bool isFavorite = false;
  String notes = '';
  Duration restDuration = const Duration(minutes: 3);
  Duration defaultRestDuration = const Duration(minutes: 3);
  Timer? restTimer;
  bool isResting = false;
  bool isWorkoutComplete = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? userGoal;
  final user = FirebaseAuth.instance.currentUser;
  String exerciseId = 'unknown'; // ← WILL BE FIXED IN initState

  @override
  void initState() {
    super.initState();
    _extractAndLoadExerciseId();
  }

  Future<void> _extractAndLoadExerciseId() async {
    // 1. Get the workout document to access exerciseIds array
    final workoutDoc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workoutId)
        .get();

    if (!workoutDoc.exists) {
      exerciseId = 'unknown';
      _loadUserDataAndSets();
      return;
    }

    final data = workoutDoc.data()!;
    final List<dynamic> exerciseIds = data['exerciseIds'] ?? [];

    // 2. Match the current exercise name with one in the array
    final exerciseName =
        widget.exercise['name']?.toString().toLowerCase() ?? '';
    String? foundId;

    for (String id in exerciseIds) {
      final exDoc = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .get();
      if (exDoc.exists) {
        final exName = exDoc['name']?.toString().toLowerCase() ?? '';
        if (exName == exerciseName) {
          foundId = id;
          break;
        }
      }
    }

    setState(() {
      exerciseId = foundId ?? 'unknown';
    });

    _loadUserDataAndSets();
  }

  Future<void> _loadUserDataAndSets() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final noteQuery = await FirebaseFirestore.instance
        .collection('exercises_notes')
        .where('userID', isEqualTo: user!.uid)
        .where('exerciseID', isEqualTo: exerciseId)
        .limit(1)
        .get();

    final loggedSetsQuery = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workoutId)
        .collection('logged_sets')
        .where('exerciseId', isEqualTo: exerciseId)
        .orderBy('set')
        .get();

    if (userDoc.exists) {
      setState(() {
        userGoal = userDoc['physicalGoal'] ?? 'build muscle';
        final savedRest = userDoc['restTime_$exerciseId'] ?? 180;
        defaultRestDuration = Duration(seconds: savedRest);
        restDuration = defaultRestDuration;
      });
    }

    if (noteQuery.docs.isNotEmpty) {
      final data = noteQuery.docs.first.data();
      setState(() {
        isFavorite = data['favorite'] == true;
        notes = data['notes'] ?? '';
      });
    }

    if (loggedSetsQuery.docs.isNotEmpty) {
      sets = loggedSetsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'docId': doc.id,
          'set': data['set'],
          'reps': data['reps'],
          'kg': data['weight'],
          'rir': data['rir'],
          'isMax': data['isMax'] ?? false,
          'isLogged': true,
        };
      }).toList();
      isWorkoutComplete = true;
    } else {
      _setupSets();
      isWorkoutComplete = false;
    }

    _updateTotals();
    setState(() {});
  }

  void _setupSets() {
    int defaultReps = 10;
    if (userGoal == 'gain strength')
      defaultReps = 15;
    else if (userGoal == 'lose weight') defaultReps = 12;

    final int setsCount = widget.exercise['sets'] ?? 4;
    for (int i = 1; i <= setsCount; i++) {
      sets.add({
        'set': i,
        'reps': defaultReps.toDouble(),
        'kg': null,
        'rir': 0.0,
        'isMax': false,
        'isLogged': false,
      });
    }
  }

  void _renumberSets() {
    for (int i = 0; i < sets.length; i++) {
      sets[i]['set'] = i + 1;
    }
  }

  @override
  void dispose() {
    restTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addSet() {
    setState(() {
      sets.add({
        'set': sets.length + 1,
        'reps': 10.0,
        'kg': null,
        'rir': 0.0,
        'isMax': false,
        'isLogged': false,
      });
    });
  }

  void _updateTotals() {
    totalReps = 0;
    totalVolume = 0.0;
    totalCalories = 0.0;
    maxWeight = 0.0;
    oneRepMax = 0.0;

    for (var set in sets) {
      final reps = set['reps'] as double?;
      final kg = set['kg'] as double?;
      if (reps != null && kg != null && set['isLogged'] == true) {
        totalReps += reps.toInt();
        totalVolume += reps * kg;
        totalCalories += reps * kg * 0.05;
        maxWeight = max(maxWeight, kg);
        final calc1RM = kg * (1 + reps / 30);
        if (calc1RM > oneRepMax) {
          oneRepMax = calc1RM;
          set['isMax'] = true;
        }
      }
    }
    setState(() {});
  }

  void _startRestTimer() {
    restTimer?.cancel();
    isResting = true;
    Duration remaining = restDuration;
    setState(() {});

    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        isResting = false;
        restDuration = defaultRestDuration;
        _audioPlayer.play(AssetSource('sounds/victory.mp3'));
        setState(() {});
        return;
      }
      remaining -= const Duration(seconds: 1);
      setState(() {
        restDuration = remaining;
      });
    });
  }

  void _adjustRest(int seconds) {
    setState(() {
      restDuration =
          Duration(seconds: max(15, restDuration.inSeconds + seconds));
    });
    if (isResting) _startRestTimer();
  }

  void _logOrComplete() async {
    final currentSet =
        sets.firstWhere((s) => s['isLogged'] == false, orElse: () => sets.last);
    if (!currentSet['isLogged'] && currentSet['kg'] != null) {
      setState(() => currentSet['isLogged'] = true);

      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .collection('logged_sets')
          .add({
        'exerciseId': exerciseId, // ← NOW 100% CORRECT FROM exerciseIds ARRAY
        'set': currentSet['set'],
        'reps': currentSet['reps'],
        'weight': currentSet['kg'],
        'rir': currentSet['rir'],
        'isMax': currentSet['isMax'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    _updateTotals();
    _startRestTimer();

    if (sets.every((s) => s['isLogged'] == true)) {
      setState(() => isWorkoutComplete = true);
      _saveToFirestore();
    }
  }

  Future<void> _saveToFirestore() async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({
      'exerciseID': exerciseId,
      'userID': user!.uid,
      'favorite': isFavorite,
      'recommend': true,
      'notes': notes,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'restTime_$exerciseId': defaultRestDuration.inSeconds,
    });
  }

  void _toggleEditMode() {
    setState(() => isWorkoutComplete = false);
  }

  void _toggleFavorite() async {
    setState(() => isFavorite = !isFavorite);
    await _saveToFirestore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.orange),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.exercise['name'] ?? 'Exercise',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.orange),
              onPressed: _toggleFavorite)
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/instructions'),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(widget.exercise['imageUrl'] ?? '',
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover)),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _totalBox('Total Reps', totalReps.toString()),
                _totalBox(
                    'Calories', '${totalCalories.toStringAsFixed(0)} kcal'),
                _totalBox('Volume', '${totalVolume.toStringAsFixed(0)} Kg'),
              ]),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: const [
                  SizedBox(
                      width: 50,
                      child: Center(
                          child: Text('Set',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)))),
                  Expanded(
                      child: Center(
                          child: Text('REPS',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)))),
                  Expanded(
                      child: Center(
                          child: Text('KG',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)))),
                  Expanded(
                      child: Center(
                          child: Text('RIR',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)))),
                ]),
              ),
              const SizedBox(height: 12),
              ...sets.asMap().entries.map((entry) {
                int idx = entry.key;
                var s = entry.value;
                final bool logged = s['isLogged'] == true;
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) async {
                    setState(() {
                      sets.removeAt(idx);
                      _renumberSets();
                    });
                    _updateTotals();
                    final snapshot = await FirebaseFirestore.instance
                        .collection('workouts')
                        .doc(widget.workoutId)
                        .collection('logged_sets')
                        .where('set', isEqualTo: s['set'])
                        .where('exerciseId', isEqualTo: exerciseId)
                        .get();
                    for (var doc in snapshot.docs) {
                      await doc.reference.delete();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: logged ? Colors.orange : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(
                          width: 50,
                          child: Center(
                              child: s['isMax'] == true
                                  ? const Icon(Icons.emoji_events,
                                      color: Colors.amber)
                                  : Text('${s['set']}',
                                      style: TextStyle(
                                          color: logged
                                              ? Colors.white
                                              : Colors.white,
                                          fontWeight: FontWeight.bold)))),
                      _numberInput(
                          (val) => setState(
                              () => s['reps'] = double.tryParse(val) ?? 0),
                          s['reps']?.toInt().toString() ?? '',
                          logged),
                      _numberInput(
                          (val) => setState(
                              () => s['kg'] = double.tryParse(val) ?? 0),
                          s['kg']?.toString().replaceAll('.0', '') ?? '',
                          logged),
                      _numberInput(
                          (val) => setState(
                              () => s['rir'] = double.tryParse(val) ?? 0),
                          s['rir']?.toInt().toString() ?? '',
                          logged),
                    ]),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                    onTap: _addSet,
                    child: const Text('+ Add Set',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                Row(children: [
                  const Text('Rest: ', style: TextStyle(color: Colors.white)),
                  Text(
                      isResting
                          ? '${restDuration.inMinutes}:${(restDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                          : '${defaultRestDuration.inMinutes}:00',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.orange),
                      onPressed: () => _adjustRest(-15)),
                  const Text('15s', style: TextStyle(color: Colors.orange)),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.orange),
                      onPressed: () => _adjustRest(15)),
                ]),
              ]),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Row(children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  Text(' 1RM: ${oneRepMax.toStringAsFixed(0)} kg',
                      style: const TextStyle(color: Colors.white))
                ]),
                Row(children: [
                  const Icon(Icons.emoji_events_outlined, color: Colors.orange),
                  Text(' Max: ${maxWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(color: Colors.white))
                ]),
              ]),
              const SizedBox(height: 24),
              if (!isWorkoutComplete)
                ElevatedButton(
                  onPressed: _logOrComplete,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 56),
                      shape: const StadiumBorder()),
                  child: Text(
                      sets.any((s) => s['isLogged'] != true)
                          ? 'Log Set'
                          : 'Complete Set',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              if (isWorkoutComplete)
                GestureDetector(
                  onTap: _toggleEditMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                      child: Text('Workout Complete! Tap here to edit',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                    hintText: 'Add notes here',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none)),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => notes = val,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Rest Time'),
          BottomNavigationBarItem(
              icon: Icon(Icons.info), label: 'Instructions'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Statistics'),
        ],
        onTap: (i) {
          if (i == 0) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                title: const Text('Adjust Rest Time',
                    style: TextStyle(color: Colors.orange)),
                content: StatefulBuilder(
                  builder: (context, setStateDialog) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        '${defaultRestDuration.inMinutes}:${(defaultRestDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 32)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.orange, size: 40),
                          onPressed: () => setStateDialog(() =>
                              defaultRestDuration = Duration(
                                  seconds: max(15,
                                      defaultRestDuration.inSeconds - 15)))),
                      IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.orange, size: 40),
                          onPressed: () => setStateDialog(() =>
                              defaultRestDuration = Duration(
                                  seconds:
                                      defaultRestDuration.inSeconds + 15))),
                    ]),
                  ]),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() => restDuration = defaultRestDuration);
                      _saveToFirestore();
                      Navigator.pop(context);
                    },
                    child: const Text('Save',
                        style: TextStyle(color: Colors.orange)),
                  )
                ],
              ),
            );
          }
          if (i == 1) Navigator.pushNamed(context, '/instructions');
        },
      ),
    );
  }

  Widget _totalBox(String label, String value) => Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ]);

  Widget _numberInput(
      ValueChanged<String> onChanged, String initialValue, bool logged) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: TextFormField(
          initialValue: initialValue,
          enabled: !logged,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: logged ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18),
          decoration: InputDecoration(
            filled: true,
            fillColor: logged
                ? Colors.orange.withOpacity(0.8)
                : const Color(0xFFE0E0E0),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
          onChanged: (val) {
            onChanged(val);
            _updateTotals();
          },
        ),
      ),
    );
  }
}
