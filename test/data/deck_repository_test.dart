import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/deck_repository.dart';
import 'package:running_tools/domain/deck.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('decks'));
  tearDown(() => dir.deleteSync(recursive: true));

  Deck deck(String id, String name) => Deck(
    id: id,
    name: name,
    cards: predefinedCards.take(3).toList(),
    recovery: const Duration(minutes: 1),
    limit: const DurationLimit(Duration(minutes: 8)),
  );

  test('ajout, remplacement, suppression', () async {
    final repo = JsonDeckRepository(dir);
    await repo.save(deck('a', 'A'));
    await repo.save(deck('a', 'A modifié'));
    await repo.save(deck('b', 'B'));
    expect((await JsonDeckRepository(dir).all()).map((d) => d.name), [
      'A modifié',
      'B',
    ]);
    await repo.delete('a');
    expect((await repo.all()).map((d) => d.id), ['b']);
  });
}
