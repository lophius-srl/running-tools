import 'dart:io';

import 'json_file_store.dart';

/// Préférences générales de l'app.
abstract interface class PreferencesRepository {
  /// Baisser la musique des autres apps pendant un test (sinon : mixée).
  Future<bool> duckOthers();
  Future<void> setDuckOthers(bool value);
}

class JsonPreferencesRepository implements PreferencesRepository {
  JsonPreferencesRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/preferences.json'));

  final JsonFileStore _store;

  @override
  Future<bool> duckOthers() async =>
      (await _store.read())?['duckOthers'] as bool? ?? true;

  @override
  Future<void> setDuckOthers(bool value) async {
    final current = await _store.read() ?? {};
    await _store.write({...current, 'version': 1, 'duckOthers': value});
  }
}
