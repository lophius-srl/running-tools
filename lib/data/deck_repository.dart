import 'dart:io';

import '../domain/deck.dart';
import 'json_file_store.dart';

/// Decks créés par l'utilisateur.
abstract interface class DeckRepository {
  Future<List<Deck>> all();
  Future<void> save(Deck deck);
  Future<void> delete(String id);
}

class JsonDeckRepository implements DeckRepository {
  JsonDeckRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/decks.json'));

  final JsonFileStore _store;

  @override
  Future<List<Deck>> all() async {
    final raw = (await _store.read())?['decks'];
    return raw is List
        ? [
            for (final d in raw)
              if (d is Map<String, Object?>) ?Deck.fromJson(d),
          ]
        : [];
  }

  @override
  Future<void> save(Deck deck) async => _write([
    for (final d in await all())
      if (d.id != deck.id) d,
    deck,
  ]);

  @override
  Future<void> delete(String id) async => _write([
    for (final d in await all())
      if (d.id != id) d,
  ]);

  Future<void> _write(List<Deck> decks) => _store.write({
    'version': 1,
    'decks': [for (final d in decks) d.toJson()],
  });
}
