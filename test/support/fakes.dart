import 'package:running_tools/data/setup_repository.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

/// Dépôt de réglages en mémoire.
class FakeSetupRepository implements SetupRepository {
  final saved = <StagedTest, StagedTestSetup>{};

  @override
  Future<StagedTestSetup?> load(StagedTest test) async => saved[test];

  @override
  Future<void> save(StagedTestSetup setup) async => saved[setup.test] = setup;
}
