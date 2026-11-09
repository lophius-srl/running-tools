import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/fartlek_repository.dart';
import 'package:running_tools/domain/fartlek.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fartleks'));
  tearDown(() => dir.deleteSync(recursive: true));

  RecentFartlek f(int seed) => RecentFartlek(
    date: DateTime(2026, 11, seed % 28 + 1),
    seed: seed,
    settings: const FartlekSettings(percentVma: 95),
  );

  test('plus récente en tête, graine rejouée remontée, limite', () async {
    final repo = JsonFartlekRepository(dir, limit: 3);
    await repo.remember(f(1));
    await repo.remember(f(2));
    await repo.remember(f(1));
    await repo.remember(f(3));
    await repo.remember(f(4));
    final reread = await JsonFartlekRepository(dir).recent();
    expect(reread.map((r) => r.seed), [4, 3, 1]);
    expect(reread.first.settings.percentVma, 95);
  });
}
