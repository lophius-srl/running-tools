import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/setup_repository.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('setup_repo'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('mémorise les réglages par test, sans écraser les autres', () async {
    final repo = JsonSetupRepository(dir);
    expect(await repo.load(StagedTest.vameval), isNull);

    final vameval = StagedTestSetup.defaults(StagedTest.vameval);
    final leger = StagedTestSetup(
      test: StagedTest.lucLeger,
      protocol: StagedTest.lucLeger.defaultProtocol.copyWith(
        markerSpacingM: 16.5,
      ),
      maxSpeedKmh: 17,
      method: vameval.method,
    );
    await repo.save(vameval);
    await repo.save(leger);

    final reread = JsonSetupRepository(dir);
    expect((await reread.load(StagedTest.vameval))!.maxSpeedKmh, 20);
    expect(
      (await reread.load(StagedTest.lucLeger))!.protocol.markerSpacingM,
      16.5,
    );
  });
}
