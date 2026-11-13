import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/profile_repository.dart';
import 'package:running_tools/domain/zones/zones.dart';

void main() {
  late Directory dir;
  late JsonProfileRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('profile');
    repo = JsonProfileRepository(dir, clock: () => DateTime(2026, 11, 13));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('saisies, année de naissance, bornes : relues ; null efface', () async {
    await repo.setManualVma(14.5);
    await repo.setManualMaxHeartRate(196);
    await repo.setBirthYear(1985);
    await repo.setSettings(const ZoneSettings().withHeartRateUpperBpm(1, 165));
    var d = await repo.read();
    expect(d.manualVma!.value, 14.5);
    expect(d.manualVma!.date, DateTime(2026, 11, 13));
    expect(d.manualMaxHeartRate!.value, 196);
    expect(d.birthYear, 1985);
    expect(d.settings.heartRateUpperBpm[1], 165);
    await repo.setManualVma(null);
    d = await repo.read();
    expect(d.manualVma, isNull);
    expect(d.manualMaxHeartRate!.value, 196);
  });

  test('versions : ajoutées seulement si les zones changent', () async {
    final a = ZoneService.compute(vmaKmh: 12);
    final b = ZoneService.compute(vmaKmh: 12.5);
    expect(await repo.recordVersion(a, DateTime(2026, 10, 1)), isTrue);
    expect(await repo.recordVersion(a, DateTime(2026, 10, 2)), isFalse);
    expect(await repo.recordVersion(b, DateTime(2026, 11, 1)), isTrue);
    final d = await repo.read();
    expect(d.versions, hasLength(2));
    // La première version ne déclenche pas d'alerte ; la seconde, si.
    expect(d.seenVersions, 1);
    await repo.markVersionsSeen();
    expect((await repo.read()).seenVersions, 2);
  });
}
