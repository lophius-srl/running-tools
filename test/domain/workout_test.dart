import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/workout.dart';
import 'package:running_tools/domain/workout_library.dart';

void main() {
  test('bibliothèque : ids uniques, séances classiques présentes', () {
    final ids = workoutLibrary.map((w) => w.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      workoutLibrary.map((w) => w.name),
      containsAll([
        '30/30',
        '45/15',
        '10 × 200 m',
        '8 × 400 m',
        '5 × 1000 m',
        'Pyramide 200-400-600-400-200',
        'Côtes 8 × 45 s',
      ]),
    );
    expect(workoutLibrary.every((w) => w.builtIn), isTrue);
  });

  test('séances en distance (lièvre) ou au temps (chrono)', () {
    Workout byName(String n) => workoutLibrary.firstWhere((w) => w.name == n);
    expect(byName('8 × 400 m').isDistanceBased, isTrue);
    expect(byName('Pyramide 200-400-600-400-200').effortCount, 5);
    expect(byName('30/30').isDistanceBased, isFalse);
  });

  test('aller-retour JSON, y compris récup en distance et sans % VMA', () {
    const workout = Workout(
      id: 'perso-1',
      name: 'Ma séance',
      sets: [
        WorkoutSet(
          reps: 3,
          effort: Effort.distance(600, percentVma: 95),
          recovery: Recovery.distance(200),
        ),
        WorkoutSet(reps: 4, effort: Effort.time(Duration(seconds: 45))),
      ],
    );
    final back = Workout.fromJson(workout.toJson())!;
    expect(back.name, 'Ma séance');
    expect(back.builtIn, isFalse);
    expect(back.sets.first.effort.distanceM, 600);
    expect(back.sets.first.effort.percentVma, 95);
    expect(back.sets.first.recovery!.distanceM, 200);
    expect(back.sets.last.effort.duration, const Duration(seconds: 45));
    expect(back.sets.last.effort.percentVma, isNull);
    expect(back.sets.last.recovery, isNull);
  });

  test('JSON illisible : null', () {
    expect(Workout.fromJson({'id': 'x'}), isNull);
  });
}
