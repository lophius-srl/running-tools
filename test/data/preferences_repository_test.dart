import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/preferences_repository.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('prefs'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('ducking activé par défaut, puis mémorisé', () async {
    final prefs = JsonPreferencesRepository(dir);
    expect(await prefs.duckOthers(), isTrue);
    await prefs.setDuckOthers(false);
    expect(await JsonPreferencesRepository(dir).duckOthers(), isFalse);
  });
}
