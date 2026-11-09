import 'dart:io';

import 'json_file_store.dart';

/// Préférences générales de l'app.
abstract interface class PreferencesRepository {
  /// Baisser la musique des autres apps pendant un test (sinon : mixée).
  Future<bool> duckOthers();
  Future<void> setDuckOthers(bool value);

  /// Longueur de chaussure mémorisée (mesure talon-pointe), en mètres.
  Future<double?> shoeLengthM();
  Future<void> setShoeLengthM(double value);
}

class JsonPreferencesRepository implements PreferencesRepository {
  JsonPreferencesRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/preferences.json'));

  final JsonFileStore _store;

  @override
  Future<bool> duckOthers() async =>
      (await _store.read())?['duckOthers'] as bool? ?? true;

  @override
  Future<void> setDuckOthers(bool value) => _set('duckOthers', value);

  @override
  Future<double?> shoeLengthM() async =>
      ((await _store.read())?['shoeLengthM'] as num?)?.toDouble();

  @override
  Future<void> setShoeLengthM(double value) => _set('shoeLengthM', value);

  Future<void> _set(String key, Object value) async {
    final current = await _store.read() ?? {};
    await _store.write({...current, 'version': 1, key: value});
  }
}
