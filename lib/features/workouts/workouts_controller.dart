import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/workout.dart';

/// Séances personnelles, rechargées après chaque modification.
class WorkoutsController extends AsyncNotifier<List<Workout>> {
  @override
  Future<List<Workout>> build() async {
    final repository = await ref.watch(workoutRepositoryProvider.future);
    return repository.all();
  }

  Future<void> save(Workout workout) async {
    final repository = await ref.read(workoutRepositoryProvider.future);
    await repository.save(workout);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String id) async {
    final repository = await ref.read(workoutRepositoryProvider.future);
    await repository.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final workoutsControllerProvider =
    AsyncNotifierProvider<WorkoutsController, List<Workout>>(
      WorkoutsController.new,
    );
