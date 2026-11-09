import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/recent_names_repository.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('names'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('les plus récents en tête, sans doublon ni nom vide, limite', () async {
    final repo = JsonRecentNamesRepository(dir, limit: 3);
    expect(await repo.recent(), isEmpty);
    await repo.remember(['Léa', 'Tom']);
    await repo.remember(['Sam', ' Léa ', '']);
    expect(await JsonRecentNamesRepository(dir).recent(), [
      'Sam',
      'Léa',
      'Tom',
    ]);
    await repo.remember(['Inès']);
    expect(await repo.recent(), ['Inès', 'Sam', 'Léa']);
  });
}
