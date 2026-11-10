import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/ghost_repository.dart';
import 'package:running_tools/domain/ghost.dart';
import 'package:running_tools/domain/gps_tracker.dart';

void main() {
  late Directory dir;
  late JsonGhostRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ghosts');
    repo = JsonGhostRepository(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('fantôme enregistré, relu, supprimé', () async {
    final ghost = Ghost(
      name: 'Boucle',
      points: const [
        GhostPoint(timeS: 0, distanceM: 0, position: GeoPoint(45, 4)),
        GhostPoint(timeS: 60, distanceM: 200, position: GeoPoint(45.001, 4)),
      ],
    );
    final saved = await repo.save(ghost);
    expect((await repo.saved()).single.name, 'Boucle');
    final back = (await repo.load(saved.id))!;
    expect(back.totalDistanceM, 200);
    expect(back.points.last.position!.latitude, 45.001);
    await repo.delete(saved.id);
    expect(await repo.saved(), isEmpty);
    expect(await repo.load(saved.id), isNull);
  });

  test('résumés de course, le plus récent d’abord', () async {
    GhostRunSummary run(int day) => GhostRunSummary(
      date: DateTime(2026, 11, day),
      ghostName: 'Allure 5:00/km',
      alignment: GhostAlignment.distance,
      distanceM: 5000,
      timeS: 1490,
      gapS: 10,
      curve: const [(100, 1), (200, 2.5)],
    );
    await repo.addRun(run(1));
    await repo.addRun(run(2));
    final runs = await repo.runs();
    expect(runs.map((r) => r.date.day), [2, 1]);
    expect(runs.first.curve.last, (200.0, 2.5));
  });
}
