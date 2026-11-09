import 'dart:io';

import 'json_file_store.dart';

/// Noms des participants récents, du plus récent au plus ancien.
abstract interface class RecentNamesRepository {
  Future<List<String>> recent();

  /// Remonte [names] en tête, sans doublon, en gardant [limit] noms.
  Future<void> remember(List<String> names);
}

class JsonRecentNamesRepository implements RecentNamesRepository {
  JsonRecentNamesRepository(Directory directory, {this.limit = 30})
    : _store = JsonFileStore(File('${directory.path}/recent_names.json'));

  final int limit;
  final JsonFileStore _store;

  @override
  Future<List<String>> recent() async {
    final raw = (await _store.read())?['names'];
    return raw is List
        ? [
            for (final n in raw)
              if (n is String) n,
          ]
        : [];
  }

  @override
  Future<void> remember(List<String> names) async {
    final cleaned = [for (final n in names) n.trim()]
      ..removeWhere((n) => n.isEmpty);
    final merged = [
      ...cleaned,
      for (final n in await recent())
        if (!cleaned.contains(n)) n,
    ];
    await _store.write({'version': 1, 'names': merged.take(limit).toList()});
  }
}
