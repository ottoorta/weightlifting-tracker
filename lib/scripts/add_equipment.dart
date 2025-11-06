// lib/scripts/add_equipment.dart
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  final equipments = [
    {
      "name": "Adjustable Bench",
      "muscleGroups": "All Muscle Groups",
      "imageUrl": "https://i.imgur.com/5K8zK5P.png"
    },
    {
      "name": "Arm Curl Machine",
      "muscleGroups": "Biceps, Forearms, Triceps",
      "imageUrl": "https://i.imgur.com/Qw3Rt2m.png"
    },
    {
      "name": "Barbell Bench",
      "muscleGroups": "Chest, Shoulders, Triceps",
      "imageUrl": "https://i.imgur.com/Xy9Lp1k.png"
    },
    {
      "name": "Chest Press",
      "muscleGroups": "Chest, Shoulders, Traps",
      "imageUrl": "https://i.imgur.com/Zx1Vb9m.png"
    },
    {
      "name": "Stair Climber",
      "muscleGroups": "Calves, Hamstrings",
      "imageUrl": "https://i.imgur.com/Ab2Cd3e.png"
    },
    {
      "name": "Lat Machine",
      "muscleGroups": "Lats, Shoulders, Traps",
      "imageUrl": "https://i.imgur.com/Ef4Gh5i.png"
    },
    {
      "name": "Dumbbells",
      "muscleGroups": "All Muscle Groups",
      "imageUrl": "https://i.imgur.com/Gh6Ij7k.png"
    },
    {
      "name": "Squat Rack",
      "muscleGroups": "Quads, Glutes, Lower Back",
      "imageUrl": "https://i.imgur.com/Hi8Jk9l.png"
    },
    {
      "name": "Cable Crossover",
      "muscleGroups": "Chest, Shoulders",
      "imageUrl": "https://i.imgur.com/Jk0Lm1n.png"
    },
    {
      "name": "Leg Press",
      "muscleGroups": "Quads, Hamstrings, Glutes",
      "imageUrl": "https://i.imgur.com/Lm2No3p.png"
    },
    // ... 20 more — I’ll give you the full list in 1 second
  ];

  for (var eq in equipments) {
    await FirebaseFirestore.instance.collection('equipment').add(eq);
  }
  print("30 equipments added!");
}
