import 'dart:io';

import '../domain/workout.dart';
import 'json_file_store.dart';

/// Séances créées par l'utilisateur.
abstract interface class WorkoutRepository {
  Future<List<Workout>> all();
  Future<void> save(Workout workout);
  Future<void> delete(String id);
}

class JsonWorkoutRepository implements WorkoutRepository {
  JsonWorkoutRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/workouts.json'));

  static const _version = 1;
  final JsonFileStore _store;

  @override
  Future<List<Workout>> all() async {
    final raw = (await _store.read())?['workouts'];
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map<String, Object?>) ?Workout.fromJson(item),
    ];
  }

  /// Ajoute, ou remplace la séance de même id.
  @override
  Future<void> save(Workout workout) async {
    final current = await all();
    final index = current.indexWhere((w) => w.id == workout.id);
    if (index >= 0) {
      current[index] = workout;
    } else {
      current.add(workout);
    }
    await _write(current);
  }

  @override
  Future<void> delete(String id) async => _write([
    for (final w in await all())
      if (w.id != id) w,
  ]);

  Future<void> _write(List<Workout> workouts) => _store.write({
    'version': _version,
    'workouts': [for (final w in workouts) w.toJson()],
  });
}
