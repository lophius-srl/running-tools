import 'dart:io';

import '../domain/debrief/debrief_summary.dart';
import 'json_file_store.dart';

abstract interface class DebriefRepository {
  /// Débriefs, du plus récent au plus ancien (date de la sortie).
  Future<List<DebriefSummary>> all();

  /// Ajoute, ou remplace celui de même id.
  Future<void> save(DebriefSummary debrief);
  Future<void> delete(String id);
}

class JsonDebriefRepository implements DebriefRepository {
  JsonDebriefRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/debriefs.json'));

  final JsonFileStore _store;

  @override
  Future<List<DebriefSummary>> all() async {
    final raw = (await _store.read())?['debriefs'];
    final list = raw is List
        ? [
            for (final d in raw)
              if (d is Map<String, Object?>) ?DebriefSummary.fromJson(d),
          ]
        : <DebriefSummary>[];
    return list..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> save(DebriefSummary debrief) async => _write([
    debrief,
    for (final d in await all())
      if (d.id != debrief.id) d,
  ]);

  @override
  Future<void> delete(String id) async => _write([
    for (final d in await all())
      if (d.id != id) d,
  ]);

  Future<void> _write(List<DebriefSummary> list) => _store.write({
    'version': 1,
    'debriefs': [for (final d in list) d.toJson()],
  });
}
