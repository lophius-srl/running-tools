import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/workout_repository.dart';
import 'package:running_tools/domain/workout.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('workouts'));
  tearDown(() => dir.deleteSync(recursive: true));

  Workout workout(String id, String name) => Workout(
    id: id,
    name: name,
    sets: const [
      WorkoutSet(reps: 6, effort: Effort.distance(300, percentVma: 100)),
    ],
  );

  test('ajout, remplacement, suppression', () async {
    final repo = JsonWorkoutRepository(dir);
    expect(await repo.all(), isEmpty);

    await repo.save(workout('a', 'A'));
    await repo.save(workout('b', 'B'));
    await repo.save(workout('a', 'A modifiée'));
    final reread = await JsonWorkoutRepository(dir).all();
    expect(reread.map((w) => w.name), ['A modifiée', 'B']);

    await repo.delete('a');
    expect((await repo.all()).map((w) => w.id), ['b']);
  });
}
