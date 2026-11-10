import 'dart:io';

import '../domain/orthostatic.dart';
import 'json_file_store.dart';

/// Résultats des tests orthostatiques et réglage du rappel.
abstract interface class OrthostaticRepository {
  /// Du plus récent au plus ancien.
  Future<List<OrthostaticResult>> all();
  Future<void> add(OrthostaticResult result);
  Future<void> delete(DateTime date);

  /// Rappel hebdomadaire : jour (1 = lundi) et heure ; `null` si aucun.
  Future<({int weekday, int hour, int minute})?> reminder();
  Future<void> setReminder(({int weekday, int hour, int minute})? value);
}

class JsonOrthostaticRepository implements OrthostaticRepository {
  JsonOrthostaticRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/orthostatic.json'));

  final JsonFileStore _store;

  Future<Map<String, Object?>> _read() async => await _store.read() ?? {};

  @override
  Future<List<OrthostaticResult>> all() async {
    final raw = (await _read())['results'];
    return raw is List
        ? ([
            for (final r in raw)
              if (r is Map<String, Object?>) ?OrthostaticResult.fromJson(r),
          ]..sort((a, b) => b.date.compareTo(a.date)))
        : [];
  }

  @override
  Future<void> add(OrthostaticResult result) async =>
      _write(results: [...await all(), result]);

  @override
  Future<void> delete(DateTime date) async => _write(
    results: [
      for (final r in await all())
        if (r.date != date) r,
    ],
  );

  @override
  Future<({int weekday, int hour, int minute})?> reminder() async {
    final r = (await _read())['reminder'];
    if (r is! Map<String, Object?>) return null;
    return (
      weekday: r['weekday']! as int,
      hour: r['hour']! as int,
      minute: r['minute']! as int,
    );
  }

  @override
  Future<void> setReminder(({int weekday, int hour, int minute})? value) =>
      _write(reminder: value, clearReminder: value == null);

  Future<void> _write({
    List<OrthostaticResult>? results,
    ({int weekday, int hour, int minute})? reminder,
    bool clearReminder = false,
  }) async {
    final current = await _read();
    final keptReminder = clearReminder
        ? null
        : (reminder ?? await this.reminder());
    await _store.write({
      'version': 1,
      'results': [for (final r in results ?? await all()) r.toJson()],
      'reminder': ?switch (keptReminder) {
        null => null,
        final r => {'weekday': r.weekday, 'hour': r.hour, 'minute': r.minute},
      },
      // Garde d'éventuels champs futurs inconnus.
      for (final e in current.entries)
        if (!const {'version', 'results', 'reminder'}.contains(e.key))
          e.key: e.value,
    });
  }
}
