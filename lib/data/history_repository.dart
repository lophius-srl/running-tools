import 'dart:io';

import '../domain/test_record.dart';
import 'json_file_store.dart';

/// Historique local des tests.
abstract interface class TestHistoryRepository {
  /// Tous les tests, du plus récent au plus ancien.
  Future<List<TestRecord>> all();
  Future<void> add(TestRecord record);
  Future<void> delete(String id);
}

class JsonHistoryRepository implements TestHistoryRepository {
  JsonHistoryRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/history.json'));

  static const _version = 1;
  final JsonFileStore _store;

  @override
  Future<List<TestRecord>> all() async {
    final raw = (await _store.read())?['records'];
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map<String, Object?>) ?TestRecord.fromJson(item),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> add(TestRecord record) async => _save([...await all(), record]);

  @override
  Future<void> delete(String id) async => _save([
    for (final r in await all())
      if (r.id != id) r,
  ]);

  Future<void> _save(List<TestRecord> records) => _store.write({
    'version': _version,
    'records': [for (final r in records) r.toJson()],
  });
}
