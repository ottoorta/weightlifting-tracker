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
  final bool isViewOnly;

  const WorkoutExerciseScreen({
    super.key,
    required this.exercise,
    required this.workoutId,
    this.isViewOnly = false,
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
  bool isLoading = true;
  String? errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? userGoal;
  final user = FirebaseAuth.instance.currentUser;
  String exerciseId = 'unknown';

  @override
  void initState() {
    super.initState();
    _extractAndLoadExerciseId();
  }

  Future<void> _extractAndLoadExerciseId() async {
    sets.clear();
    isWorkoutComplete = false;
    isLoading = true;
    errorMessage = null;

    try {
      final String? directId = widget.exercise['id']?.toString();
      if (directId != null && directId.isNotEmpty && directId != 'unknown') {
        exerciseId = directId;
        debugPrint('DIRECT ID: $exerciseId');
        await _loadUserDataAndSets();
        return;
      }

      final workoutDoc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .get();

      if (!workoutDoc.exists) {
        exerciseId = 'unknown';
        await _loadUserDataAndSets();
        return;
      }

      final data = workoutDoc.data()!;
      final List<dynamic> exerciseIds = data['exerciseIds'] ?? [];
      final exerciseName =
          widget.exercise['name']?.toString().toLowerCase() ?? '';

      for (String id in exerciseIds) {
        final doc = await FirebaseFirestore.instance
            .collection('exercises')
            .doc(id)
            .get();
        if (doc.exists &&
            doc['name']?.toString().toLowerCase() == exerciseName) {
          exerciseId = id;
          await _loadUserDataAndSets();
          return;
        }
      }

      exerciseId = 'unknown';
    } catch (e) {
      debugPrint('ID ERROR: $e');
    } finally {
      if (mounted) await _loadUserDataAndSets();
    }
  }

  Future<void> _loadUserDataAndSets() async {
    sets.clear();
    isWorkoutComplete = false;

    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please sign in.';
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          // Safe goal loading
          userGoal = userDoc.get('physicalGoal') ??
              userDoc.get('physical_goal') ??
              userDoc.get('goal') ??
              'build muscle';

          // SINGLE GLOBAL REST TIME — CLEAN & SIMPLE
          final savedSeconds = userDoc.get('defaultRestTime') ?? 180;
          defaultRestDuration = Duration(seconds: savedSeconds);
          restDuration = defaultRestDuration;
          debugPrint('Global rest time loaded: ${savedSeconds}s');
        });
      } else {
        debugPrint('User doc missing — using defaults');
        userGoal = 'build muscle';
      }

      // Notes (safe)
      try {
        final noteQuery = await FirebaseFirestore.instance
            .collection('exercises_notes')
            .where('userID', isEqualTo: user!.uid)
            .where('exerciseID', isEqualTo: exerciseId)
            .limit(1)
            .get();

        if (noteQuery.docs.isNotEmpty) {
          final data = noteQuery.docs.first.data();
          setState(() {
            isFavorite = data['favorite'] == true;
            notes = data['notes'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Notes failed: $e');
      }

      // Logged sets
      try {
        final loggedSetsQuery = await FirebaseFirestore.instance
            .collection('workouts')
            .doc(widget.workoutId)
            .collection('logged_sets')
            .where('exerciseId', isEqualTo: exerciseId)
            .orderBy('set')
            .get();

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
        }
      } catch (e) {
        debugPrint('Logged sets failed: $e');
        _setupSets();
      }
    } catch (e) {
      debugPrint('LOAD ERROR: $e');
      setState(() {
        errorMessage = 'Using defaults.';
      });
      _setupSets();
    } finally {
      _updateTotals();
      setState(() => isLoading = false);
    }
  }

  void _setupSets() {
    int defaultReps = 10;
    if (userGoal == 'gain strength')
      defaultReps = 15;
    else if (userGoal == 'lose weight') defaultReps = 12;

    final setsCount = widget.exercise['sets'] ?? 4;
    sets.clear();
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

  @override
  void dispose() {
    restTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addSet() {
    if (widget.isViewOnly) return;
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
    totalVolume = totalCalories = maxWeight = oneRepMax = 0.0;

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
    var remaining = restDuration;
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
      setState(() => restDuration = remaining);
    });
  }

  void _adjustRest(int seconds) {
    if (widget.isViewOnly) return;
    setState(() {
      restDuration =
          Duration(seconds: max(15, restDuration.inSeconds + seconds));
    });
    if (isResting) _startRestTimer();
  }

  void _logOrComplete() async {
    if (widget.isViewOnly) return;

    final currentSet =
        sets.firstWhere((s) => s['isLogged'] == false, orElse: () => sets.last);
    if (!currentSet['isLogged'] && currentSet['kg'] != null) {
      setState(() => currentSet['isLogged'] = true);

      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .collection('logged_sets')
          .add({
        'exerciseId': exerciseId,
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

  // CLEAN SAVE — ONLY ONE FIELD: defaultRestTime
  Future<void> _saveToFirestore() async {
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'defaultRestTime': defaultRestDuration.inSeconds,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({
      'exerciseID': exerciseId,
      'userID': user!.uid,
      'favorite': isFavorite,
      'notes': notes,
    }, SetOptions(merge: true));
  }

  void _toggleEditMode() => setState(() => isWorkoutComplete = false);
  void _toggleFavorite() async {
    if (widget.isViewOnly) return;
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orange))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  if (errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent, width: 1),
                      ),
                      child: Column(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 48),
                        const SizedBox(height: 8),
                        Text(errorMessage!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            _extractAndLoadExerciseId();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: const Text("Retry"),
                        ),
                      ]),
                    ),
                  ],

                  // IMAGE + TOTALS + SETS + REST TIMER (unchanged)
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
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _totalBox('Total Reps', totalReps.toString()),
                        _totalBox('Calories',
                            '${totalCalories.toStringAsFixed(0)} kcal'),
                        _totalBox(
                            'Volume', '${totalVolume.toStringAsFixed(0)} Kg'),
                      ]),
                  const SizedBox(height: 24),
                  ...sets.map((s) {
                    final logged = s['isLogged'] == true;
                    return Card(
                      color: logged
                          ? Colors.orange.withOpacity(0.2)
                          : const Color(0xFF1C1C1E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Text(logged ? 'Set ${s['set']}' : 'Set ${s['set']}',
                              style: TextStyle(
                                  color: logged ? Colors.orange : Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
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
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!widget.isViewOnly)
                          GestureDetector(
                              onTap: _addSet,
                              child: const Text('+ Add Set',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                        Row(children: [
                          const Text('Rest: ',
                              style: TextStyle(color: Colors.white)),
                          Text(
                              isResting
                                  ? '${restDuration.inMinutes}:${(restDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                                  : '${defaultRestDuration.inMinutes}:00',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          if (!widget.isViewOnly) ...[
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.orange),
                                onPressed: () => _adjustRest(-15)),
                            const Text('15s',
                                style: TextStyle(color: Colors.orange)),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Colors.orange),
                                onPressed: () => _adjustRest(15)),
                          ],
                        ]),
                      ]),
                  const SizedBox(height: 20),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(children: [
                          const Icon(Icons.emoji_events, color: Colors.amber),
                          Text(' 1RM: ${oneRepMax.toStringAsFixed(0)} kg',
                              style: const TextStyle(color: Colors.white))
                        ]),
                        Row(children: [
                          const Icon(Icons.emoji_events_outlined,
                              color: Colors.orange),
                          Text(' Max: ${maxWeight.toStringAsFixed(1)} kg',
                              style: const TextStyle(color: Colors.white))
                        ]),
                      ]),
                  const SizedBox(height: 24),
                  if (!isWorkoutComplete && !widget.isViewOnly)
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
                      onTap: widget.isViewOnly ? null : _toggleEditMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: Text(
                              widget.isViewOnly
                                  ? 'Workout Completed - View Only'
                                  : 'Workout Complete! Tap here to edit',
                              style: const TextStyle(
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
                    onChanged: widget.isViewOnly ? null : (val) => notes = val,
                  ),
                  const SizedBox(height: 80),
                ]),
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
          if (i == 0 && !widget.isViewOnly) {
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
                    onPressed: () async {
                      setState(() => restDuration = defaultRestDuration);
                      await _saveToFirestore();
                      if (mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Rest time saved for all workouts!'),
                            backgroundColor: Colors.green),
                      );
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
          enabled: !logged && !widget.isViewOnly,
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
