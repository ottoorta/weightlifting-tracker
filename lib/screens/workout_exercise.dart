// lib/screens/workout_exercise.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'instructions_screen.dart';

class WorkoutExerciseScreen extends StatefulWidget {
  final String workoutId;
  final Map<String, dynamic> exercise;
  final bool isWorkoutStarted;
  final bool isViewOnly; // ← REQUIRED: used throughout the screen

  const WorkoutExerciseScreen({
    super.key,
    required this.workoutId,
    required this.exercise,
    required this.isWorkoutStarted,
    this.isViewOnly = false, // default false for normal use
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
  final TextEditingController _notesController = TextEditingController();

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
  String weightUnit = 'KG';

  int _uniqueIdCounter = 0;

  // VIDEO
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasVideo = false;
  bool _videoError = false;
  late PageController _pageController;
  int _currentPage = 0;

  // LOG BUTTON VISIBILITY
  bool _showLogButton = true;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page?.round() ?? 0;
        });
      }
    });

    _extractAndLoadExerciseId();

    // Disable logging if workout not started
    if (!widget.isWorkoutStarted) {
      _showLogButton = false;
    }
  }

  @override
  void dispose() {
    restTimer?.cancel();
    _notesController.dispose();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _addSet() {
    if (widget.isViewOnly || !widget.isWorkoutStarted) return;
    setState(() {
      sets.add({
        'set': sets.length + 1,
        'reps': 10.0,
        'kg': null,
        'rir': null,
        'isMax': false,
        'isLogged': false,
        'uniqueId': _uniqueIdCounter++,
      });
    });
  }

  Future<void> _extractAndLoadExerciseId() async {
    sets.clear();
    isWorkoutComplete = false;
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final String? directId = widget.exercise['id']?.toString();
      if (directId != null && directId.isNotEmpty && directId != 'unknown') {
        exerciseId = directId;
        await _loadUserSettingsAndData();
        return;
      }

      final workoutDoc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .get();

      if (!workoutDoc.exists) {
        exerciseId = 'unknown';
        await _loadUserSettingsAndData();
        return;
      }

      final data = workoutDoc.data()!;
      final List<dynamic> exerciseIds = data['exerciseIds'] ?? [];
      final exerciseName =
          widget.exercise['name']?.toString().toLowerCase() ?? '';

      for (String id in exerciseIds) {
        var doc = await FirebaseFirestore.instance
            .collection('exercises')
            .doc(id)
            .get();
        if (doc.exists &&
            doc['name']?.toString().toLowerCase() == exerciseName) {
          exerciseId = id;
          await _loadUserSettingsAndData();
          return;
        }

        doc = await FirebaseFirestore.instance
            .collection('exercises_custom')
            .doc(id)
            .get();
        if (doc.exists &&
            doc['name']?.toString().toLowerCase() == exerciseName) {
          exerciseId = id;
          await _loadUserSettingsAndData();
          return;
        }
      }

      exerciseId = 'unknown';
    } catch (e) {
      debugPrint('ID ERROR: $e');
    } finally {
      if (mounted) await _loadUserSettingsAndData();
    }
  }

  Future<void> _loadUserSettingsAndData() async {
    if (!mounted) return;
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
          userGoal = userDoc.get('physicalGoal') ??
              userDoc.get('physical_goal') ??
              userDoc.get('goal') ??
              'build muscle';

          final savedSeconds = userDoc.get('defaultRestTime') ?? 180;
          defaultRestDuration = Duration(seconds: savedSeconds);
          restDuration = defaultRestDuration;

          weightUnit = userDoc.get('weightUnit') == 'LB' ? 'LB' : 'KG';
        });
      }

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
          _notesController.text = notes;
        });
      }

      var exDoc = await FirebaseFirestore.instance
          .collection('exercises')
          .doc(exerciseId)
          .get();

      if (!exDoc.exists) {
        exDoc = await FirebaseFirestore.instance
            .collection('exercises_custom')
            .doc(exerciseId)
            .get();
      }

      if (exDoc.exists) {
        final videoUrl = exDoc['videoUrl'] as String?;
        if (videoUrl != null && videoUrl.trim().isNotEmpty) {
          await _initializeVideoSafely(videoUrl.trim());
        }
      }

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
            'uniqueId': doc.id,
          };
        }).toList();
        isWorkoutComplete = true;
      } else {
        _setupSets();
      }
    } catch (e) {
      debugPrint('LOAD ERROR: $e');
      setState(() => errorMessage = 'Using defaults.');
      _setupSets();
    } finally {
      _updateTotals();
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _initializeVideoSafely(String url) async {
    _hasVideo = true;
    _videoError = false;

    try {
      _videoController = VideoPlayerController.network(url);
      await _videoController!.initialize();
      _videoController!.setVolume(0);

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: true,
        allowMuting: true,
        showControls: true,
        errorBuilder: (context, errorMessage) => _buildVideoErrorWidget(),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.orange,
          handleColor: Colors.orange,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white30,
        ),
      );
    } catch (e) {
      debugPrint("VIDEO INIT FAILED: $e");
      _videoError = true;
      _videoController?.dispose();
      _videoController = null;
    }

    if (mounted) setState(() {});
  }

  Widget _buildVideoErrorWidget() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.orange, size: 48),
            SizedBox(height: 8),
            Text("Video unavailable", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotes() async {
    if (user == null || widget.isViewOnly) return;

    await FirebaseFirestore.instance
        .collection('exercises_notes')
        .doc('${user!.uid}_$exerciseId')
        .set({
      'exerciseID': exerciseId,
      'userID': user!.uid,
      'favorite': isFavorite,
      'notes': _notesController.text,
    }, SetOptions(merge: true));
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
        'rir': null,
        'isMax': false,
        'isLogged': false,
        'uniqueId': _uniqueIdCounter++,
      });
    }
  }

  Future<void> _deleteSet(int index) async {
    final set = sets[index];
    final docId = set['docId'];
    final wasLogged = set['isLogged'] == true;

    setState(() {
      sets.removeAt(index);
      for (int i = index; i < sets.length; i++) {
        sets[i]['set'] = i + 1;
      }
    });

    if (wasLogged && docId != null) {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .collection('logged_sets')
          .doc(docId)
          .delete();
    }

    _updateTotals();
  }

  void _updateTotals() {
    totalReps = 0;
    totalVolume = totalCalories = maxWeight = oneRepMax = 0.0;

    for (var s in sets) {
      final reps = s['reps'] as double?;
      final kg = s['kg'] as double?;
      if (reps != null && kg != null && s['isLogged'] == true) {
        totalReps += reps.toInt();
        totalVolume += reps * kg;
        totalCalories += reps * kg * 0.05;
        if (kg > maxWeight) maxWeight = kg;

        final calc1RM = kg * (1 + reps / 30);
        if (calc1RM > oneRepMax) {
          oneRepMax = calc1RM;
          s['isMax'] = true;
        }
      }
    }

    for (var s in sets) {
      final reps = s['reps'] as double?;
      final kg = s['kg'] as double?;
      if (reps != null && kg != null && s['isLogged'] == true) {
        final calc1RM = kg * (1 + reps / 30);
        s['isMax'] = calc1RM >= oneRepMax;
      }
    }

    if (mounted) setState(() {});
  }

  void _startRestTimer() {
    restTimer?.cancel();
    isResting = true;
    _showLogButton = false;
    Duration remaining = restDuration;

    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        setState(() {
          isResting = false;
          restDuration = defaultRestDuration;
          _showLogButton = true;
        });
        _audioPlayer.play(AssetSource('sounds/victory.mp3'));
        return;
      }
      remaining -= const Duration(seconds: 1);
      setState(() => restDuration = remaining);
    });
  }

  void _adjustRest(int seconds) {
    if (widget.isViewOnly) return; // ← FIXED: was 887widget
    setState(() {
      restDuration =
          Duration(seconds: (restDuration.inSeconds + seconds).clamp(15, 3600));
    });
    if (isResting) _startRestTimer();
  }

  void _logOrComplete() async {
    if (widget.isViewOnly || !widget.isWorkoutStarted) return;

    final currentSet =
        sets.firstWhere((s) => s['isLogged'] != true, orElse: () => sets.last);
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
      await _saveToFirestore();
    }
  }

  Future<void> _saveToFirestore() async {
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'defaultRestTime': defaultRestDuration.inSeconds,
    }, SetOptions(merge: true));

    await _saveNotes();
  }

  void _toggleEditMode() => setState(() => isWorkoutComplete = false);
  void _toggleFavorite() async {
    if (widget.isViewOnly) return;
    setState(() => isFavorite = !isFavorite);
    await _saveNotes();
  }

  void _openFullScreenVideo() {
    if (_chewieController == null || _videoError) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: _videoError
                ? _buildVideoErrorWidget()
                : Chewie(controller: _chewieController!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = _hasVideo && !_videoError ? 2 : 1;

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // IMAGE + VIDEO CAROUSEL
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF1C1C1E),
                        ),
                        child: Stack(
                          children: [
                            PageView(
                              controller: _pageController,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    widget.exercise['imageUrl'] ?? '',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.fitness_center,
                                          size: 80, color: Colors.white54),
                                    ),
                                  ),
                                ),
                                if (_hasVideo)
                                  GestureDetector(
                                    onTap: _openFullScreenVideo,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: _videoError
                                              ? _buildVideoErrorWidget()
                                              : (_chewieController != null
                                                  ? Chewie(
                                                      controller:
                                                          _chewieController!)
                                                  : const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              color: Colors
                                                                  .orange))),
                                        ),
                                        if (!_videoError)
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle),
                                              child: const Icon(
                                                  Icons.play_arrow,
                                                  size: 60,
                                                  color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (_currentPage > 0)
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left,
                                      size: 40, color: Colors.white70),
                                  onPressed: () => _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.ease),
                                ),
                              ),
                            if (_currentPage < totalPages - 1)
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right,
                                      size: 40, color: Colors.white70),
                                  onPressed: () => _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.ease),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // BANNER: Workout not started
                      if (!widget.isWorkoutStarted)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    'Start the workout first to log sets.',
                                    style: TextStyle(color: Colors.orange)),
                              ),
                            ],
                          ),
                        ),

                      // HEADER ROW
                      Row(
                        children: [
                          const SizedBox(width: 50),
                          _headerCell("REPS", "per arm"),
                          _headerCell("WEIGHT", "($weightUnit)"),
                          _headerCell("RIR", "reps in reserve"),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // SET ROWS
                      ...sets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final s = entry.value;
                        final logged = s['isLogged'] == true;
                        final is1RM = s['isMax'] == true;
                        final isMaxWeight = s['kg'] == maxWeight && !is1RM;

                        return Dismissible(
                          key: Key(s['uniqueId'].toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete,
                                color: Colors.white, size: 30),
                          ),
                          onDismissed: (_) => _deleteSet(index),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: logged
                                  ? Colors.orange.withOpacity(0.2)
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (is1RM)
                                        const Icon(Icons.emoji_events,
                                            color: Colors.amber, size: 20),
                                      if (isMaxWeight && !is1RM)
                                        const Icon(Icons.emoji_events_outlined,
                                            color: Colors.orange, size: 20),
                                      if (!is1RM && !isMaxWeight)
                                        Text('Set ${s['set']}',
                                            style: TextStyle(
                                                color: logged
                                                    ? Colors.orange
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _numberInput(
                                    (val) => setState(() =>
                                        s['reps'] = double.tryParse(val) ?? 0),
                                    s['reps']?.toInt().toString() ?? '',
                                    logged),
                                _numberInput(
                                    (val) => setState(() =>
                                        s['kg'] = double.tryParse(val) ?? 0),
                                    s['kg']?.toString().replaceAll('.0', '') ??
                                        '',
                                    logged),
                                _numberInput(
                                    (val) => setState(() =>
                                        s['rir'] = double.tryParse(val) ?? 0),
                                    s['rir']?.toInt().toString() ?? '',
                                    logged),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 20),

                      // REST TIMER
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
                                  : '${defaultRestDuration.inMinutes}:${(defaultRestDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
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
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(children: [
                            const Icon(Icons.emoji_events, color: Colors.amber),
                            Text(
                                ' 1RM: ${oneRepMax.toStringAsFixed(0)} $weightUnit',
                                style: const TextStyle(color: Colors.white))
                          ]),
                          Row(children: [
                            const Icon(Icons.emoji_events_outlined,
                                color: Colors.orange),
                            Text(
                                ' Max: ${maxWeight.toStringAsFixed(1)} $weightUnit',
                                style: const TextStyle(color: Colors.white))
                          ]),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // LOG BUTTON
                      if (_showLogButton &&
                          !isWorkoutComplete &&
                          !widget.isViewOnly)
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
                                      : 'Workout Complete! Tap to edit',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // NOTES
                      TextField(
                        controller: _notesController,
                        enabled: !widget.isViewOnly,
                        onChanged: (_) => _saveNotes(),
                        decoration: InputDecoration(
                            hintText: 'Add notes here',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF1C1C1E),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none)),
                        style: const TextStyle(color: Colors.white),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
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
                                  seconds: (defaultRestDuration.inSeconds - 15)
                                      .clamp(15, 3600)))),
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
                            content: Text('Rest time saved!'),
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
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      InstructionsScreen(exercise: widget.exercise)),
            );
          }
        },
      ),
    );
  }

  Widget _headerCell(String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _numberInput(
      ValueChanged<String> onChanged, String initialValue, bool logged) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: TextFormField(
          initialValue: initialValue,
          enabled: !logged && !widget.isViewOnly && widget.isWorkoutStarted,
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
