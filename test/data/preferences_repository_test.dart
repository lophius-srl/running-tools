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

  test('longueur de chaussure mémorisée sans écraser le reste', () async {
    final prefs = JsonPreferencesRepository(dir);
    expect(await prefs.shoeLengthM(), isNull);
    await prefs.setDuckOthers(false);
    await prefs.setShoeLengthM(0.295);
    final reread = JsonPreferencesRepository(dir);
    expect(await reread.shoeLengthM(), 0.295);
    expect(await reread.duckOthers(), isFalse);
  });
}
