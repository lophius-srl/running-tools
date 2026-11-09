import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/history_repository.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/test_record.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('history'));
  tearDown(() => dir.deleteSync(recursive: true));

  final vameval = TestRecord(
    id: 'a',
    date: DateTime(2026, 11, 2, 18, 30),
    kind: TestKind.vameval,
    vmaKmh: 14.75,
    vo2max: 51.6,
    distanceM: 2725,
    completedStages: 14,
    fractionOfNextStage: 0.5,
    prorata: true,
    protocol: StagedTest.vameval.defaultProtocol.copyWith(
      markerSpacingM: 23.77,
    ),
    method: MeasurementMethod.shoe,
    shoes: 'Pegasus 41',
  );
  final cooper = TestRecord(
    id: 'b',
    date: DateTime(2026, 11, 9, 8),
    kind: TestKind.cooper,
    vmaKmh: 14,
    vo2max: 51.3,
    distanceM: 2800,
  );

  test('fichier absent : historique vide', () async {
    expect(await JsonHistoryRepository(dir).all(), isEmpty);
  });

  test('aller-retour complet, plus récent en premier', () async {
    final repo = JsonHistoryRepository(dir);
    await repo.add(vameval);
    await repo.add(cooper);

    final records = await JsonHistoryRepository(dir).all();
    expect(records.map((r) => r.id), ['b', 'a']);

    final r = records.last;
    expect(r.date, DateTime(2026, 11, 2, 18, 30));
    expect(r.kind, TestKind.vameval);
    expect(r.vmaKmh, 14.75);
    expect(r.completedStages, 14);
    expect(r.fractionOfNextStage, 0.5);
    expect(r.prorata, isTrue);
    expect(r.protocol!.markerSpacingM, 23.77);
    expect(r.protocol!.stageDuration, const Duration(minutes: 1));
    expect(r.method, MeasurementMethod.shoe);
    expect(r.shoes, 'Pegasus 41');

    final c = records.first;
    expect(c.protocol, isNull);
    expect(c.method, isNull);
    expect(c.completedStages, isNull);
  });

  test('format versionné', () async {
    await JsonHistoryRepository(dir).add(cooper);
    final text = File('${dir.path}/history.json').readAsStringSync();
    expect(text, contains('"version":1'));
  });

  test('suppression', () async {
    final repo = JsonHistoryRepository(dir);
    await repo.add(vameval);
    await repo.add(cooper);
    await repo.delete('a');
    expect((await repo.all()).map((r) => r.id), ['b']);
  });

  test('fichier corrompu : mis de côté, historique vide', () async {
    File('${dir.path}/history.json').writeAsStringSync('{oups');
    expect(await JsonHistoryRepository(dir).all(), isEmpty);
    expect(File('${dir.path}/history.json.corrupt').existsSync(), isTrue);
  });

  test('un enregistrement illisible est ignoré, pas les autres', () async {
    await JsonHistoryRepository(dir).add(cooper);
    final file = File('${dir.path}/history.json');
    file.writeAsStringSync(
      file.readAsStringSync().replaceFirst(
        '"records":[',
        '"records":[{"id":"x","kind":"inconnu"},',
      ),
    );
    expect((await JsonHistoryRepository(dir).all()).map((r) => r.id), ['b']);
  });
}
