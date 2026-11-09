import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'history_repository.dart';
import 'preferences_repository.dart';
import 'setup_repository.dart';
import 'workout_repository.dart';

/// Dépôt des réglages ; remplacé par une fausse version dans les tests.
final setupRepositoryProvider = FutureProvider<SetupRepository>(
  (ref) async => JsonSetupRepository(await getApplicationDocumentsDirectory()),
);

final preferencesRepositoryProvider = FutureProvider<PreferencesRepository>(
  (ref) async =>
      JsonPreferencesRepository(await getApplicationDocumentsDirectory()),
);

final historyRepositoryProvider = FutureProvider<TestHistoryRepository>(
  (ref) async =>
      JsonHistoryRepository(await getApplicationDocumentsDirectory()),
);

final workoutRepositoryProvider = FutureProvider<WorkoutRepository>(
  (ref) async =>
      JsonWorkoutRepository(await getApplicationDocumentsDirectory()),
);

/// VMA du test le plus récent de l'historique ; `null` sans historique.
final lastVmaProvider = FutureProvider<double?>((ref) async {
  final history = await ref.watch(historyRepositoryProvider.future);
  final records = await history.all();
  return records.isEmpty ? null : records.first.vmaKmh;
});
