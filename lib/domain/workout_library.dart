import 'workout.dart';

/// Séances classiques de développement de la VMA.
const workoutLibrary = [
  Workout(
    id: 'lib-30-30',
    name: '30/30',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 10,
        effort: Effort.time(Duration(seconds: 30), percentVma: 100),
        recovery: Recovery.time(Duration(seconds: 30)),
      ),
    ],
  ),
  Workout(
    id: 'lib-45-15',
    name: '45/15',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 10,
        effort: Effort.time(Duration(seconds: 45), percentVma: 100),
        recovery: Recovery.time(Duration(seconds: 15)),
      ),
    ],
  ),
  Workout(
    id: 'lib-10x200',
    name: '10 × 200 m',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 10,
        effort: Effort.distance(200, percentVma: 105),
        recovery: Recovery.time(Duration(seconds: 45)),
      ),
    ],
  ),
  Workout(
    id: 'lib-8x400',
    name: '8 × 400 m',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 8,
        effort: Effort.distance(400, percentVma: 100),
        recovery: Recovery.time(Duration(seconds: 90)),
      ),
    ],
  ),
  Workout(
    id: 'lib-5x1000',
    name: '5 × 1000 m',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 5,
        effort: Effort.distance(1000, percentVma: 92),
        recovery: Recovery.time(Duration(seconds: 120)),
      ),
    ],
  ),
  Workout(
    id: 'lib-pyramide',
    name: 'Pyramide 200-400-600-400-200',
    builtIn: true,
    sets: [
      WorkoutSet(
        reps: 1,
        effort: Effort.distance(200, percentVma: 100),
        recovery: Recovery.time(Duration(seconds: 60)),
      ),
      WorkoutSet(
        reps: 1,
        effort: Effort.distance(400, percentVma: 97),
        recovery: Recovery.time(Duration(seconds: 90)),
      ),
      WorkoutSet(
        reps: 1,
        effort: Effort.distance(600, percentVma: 95),
        recovery: Recovery.time(Duration(seconds: 120)),
      ),
      WorkoutSet(
        reps: 1,
        effort: Effort.distance(400, percentVma: 97),
        recovery: Recovery.time(Duration(seconds: 90)),
      ),
      WorkoutSet(reps: 1, effort: Effort.distance(200, percentVma: 100)),
    ],
  ),
  Workout(
    id: 'lib-cotes',
    name: 'Côtes 8 × 45 s',
    builtIn: true,
    sets: [
      // En côte : pas d'allure cible, effort au ressenti.
      WorkoutSet(
        reps: 8,
        effort: Effort.time(Duration(seconds: 45)),
        recovery: Recovery.time(Duration(seconds: 90)),
      ),
    ],
  ),
];
