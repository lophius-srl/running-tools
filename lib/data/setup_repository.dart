import 'dart:io';

import '../domain/stage_protocol.dart';
import '../domain/staged_test_setup.dart';
import 'json_file_store.dart';

/// Derniers réglages utilisés, par test.
abstract interface class SetupRepository {
  Future<StagedTestSetup?> load(StagedTest test);
  Future<void> save(StagedTestSetup setup);
}

class JsonSetupRepository implements SetupRepository {
  JsonSetupRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/staged_setups.json'));

  static const _version = 1;
  final JsonFileStore _store;

  @override
  Future<StagedTestSetup?> load(StagedTest test) async {
    final setups = (await _store.read())?['setups'];
    if (setups is! Map<String, Object?>) return null;
    final json = setups[test.name];
    return json is Map<String, Object?> ? StagedTestSetup.fromJson(json) : null;
  }

  @override
  Future<void> save(StagedTestSetup setup) async {
    final current = await _store.read();
    final setups = {
      ...?(current?['setups'] as Map<String, Object?>?),
      setup.test.name: setup.toJson(),
    };
    await _store.write({'version': _version, 'setups': setups});
  }
}
