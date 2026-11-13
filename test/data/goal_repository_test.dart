import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/goal_repository.dart';
import 'package:running_tools/domain/goal/race_goal.dart';

void main() {
  late Directory dir;
  late JsonGoalRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('goals');
    repo = JsonGoalRepository(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  RaceGoal goal(String id, int month) => RaceGoal(
    id: id,
    name: id,
    date: DateTime(2026, month, 10),
    distanceM: 10000,
  );

  test('un seul objectif actif : le nouveau archive l’ancien', () async {
    await repo.save(goal('printemps', 4));
    await repo.save(goal('automne', 10));
    final all = await repo.all();
    expect(all.map((g) => (g.id, g.archived)), [
      ('automne', false),
      ('printemps', true),
    ]);
    expect((await repo.active())!.id, 'automne');
  });

  test('archiver l’actif : mode libre ; supprimer', () async {
    await repo.save(goal('a', 4));
    await repo.save(goal('a', 4).copyWith(archived: true));
    expect(await repo.active(), isNull);
    expect(await repo.all(), hasLength(1));
    await repo.delete('a');
    expect(await repo.all(), isEmpty);
  });
}
