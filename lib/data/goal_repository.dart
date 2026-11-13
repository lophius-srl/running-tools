import 'dart:io';

import '../domain/goal/race_goal.dart';
import 'json_file_store.dart';

abstract interface class GoalRepository {
  /// Tous les objectifs, le plus proche (ou le plus récent) en premier.
  Future<List<RaceGoal>> all();

  /// L'objectif actif, `null` en mode libre.
  Future<RaceGoal?> active();

  /// Enregistre ; un objectif actif archive l'ancien (un seul à la fois).
  Future<void> save(RaceGoal goal);
  Future<void> delete(String id);
}

class JsonGoalRepository implements GoalRepository {
  JsonGoalRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/goals.json'));

  final JsonFileStore _store;

  @override
  Future<List<RaceGoal>> all() async {
    final raw = (await _store.read())?['goals'];
    final list = raw is List
        ? [
            for (final g in raw)
              if (g is Map<String, Object?>) ?RaceGoal.fromJson(g),
          ]
        : <RaceGoal>[];
    return list..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<RaceGoal?> active() async =>
      (await all()).where((g) => !g.archived).firstOrNull;

  @override
  Future<void> save(RaceGoal goal) async => _write([
    goal,
    for (final g in await all())
      if (g.id != goal.id)
        !goal.archived && !g.archived ? g.copyWith(archived: true) : g,
  ]);

  @override
  Future<void> delete(String id) async => _write([
    for (final g in await all())
      if (g.id != id) g,
  ]);

  Future<void> _write(List<RaceGoal> goals) => _store.write({
    'version': 1,
    'goals': [for (final g in goals) g.toJson()],
  });
}
