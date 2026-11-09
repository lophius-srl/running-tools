import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/orthostatic_repository.dart';
import 'package:running_tools/domain/orthostatic.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('ortho'));
  tearDown(() => dir.deleteSync(recursive: true));

  OrthostaticResult r(int day) => OrthostaticResult(
    date: DateTime(2026, 11, day, 7),
    lyingBpm: 50,
    standingPeakBpm: 85,
    standingStableBpm: 70,
    source: HeartRateSourceKind.manual,
  );

  test('résultats du plus récent au plus ancien, rappel conservé', () async {
    final repo = JsonOrthostaticRepository(dir);
    await repo.setReminder((weekday: 1, hour: 7, minute: 0));
    await repo.add(r(2));
    await repo.add(r(9));
    final reread = JsonOrthostaticRepository(dir);
    expect((await reread.all()).map((x) => x.date.day), [9, 2]);
    expect(await reread.reminder(), (weekday: 1, hour: 7, minute: 0));

    await repo.setReminder(null);
    expect(await repo.reminder(), isNull);
    expect(await repo.all(), hasLength(2));

    await repo.delete(DateTime(2026, 11, 2, 7));
    expect((await repo.all()).single.date.day, 9);
  });
}
