import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/track_builder.dart';
import 'package:running_tools/audio/track_service.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

void main() {
  late Directory dir;
  late int builds;
  String? voiceError;

  Future<BuiltTrack> fakeBuild({
    required schedule,
    required renderer,
    required String testName,
    required Directory workDir,
    required String outputPath,
    void Function(String step)? onProgress,
  }) async {
    builds++;
    File(outputPath).writeAsStringSync('wav');
    return BuiltTrack(path: outputPath, bytes: 3, voiceError: voiceError);
  }

  final vameval = StagedTestSetup.defaults(StagedTest.vameval);
  final leger = StagedTestSetup.defaults(StagedTest.lucLeger);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tracks');
    builds = 0;
    voiceError = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<String> trackFiles() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList();

  test('mêmes réglages : piste réutilisée', () async {
    final service = CachedTrackService(dir, build: fakeBuild);
    final first = await service.prepare(vameval);
    final second = await service.prepare(vameval);
    expect(builds, 1);
    expect(second.path, first.path);
    expect(second.schedule.durationS, 25 * 60);
  });

  test(
    'nouveaux réglages : nouvelle piste, l\'ancienne est supprimée',
    () async {
      final service = CachedTrackService(dir, build: fakeBuild);
      await service.prepare(vameval);
      await service.prepare(leger);
      expect(builds, 2);
      expect(trackFiles(), hasLength(1));
    },
  );

  test('voix en échec : piste jouable mais pas mise en cache', () async {
    voiceError = 'tts';
    final service = CachedTrackService(dir, build: fakeBuild);
    final track = await service.prepare(vameval);
    expect(track.voiceError, 'tts');
    expect(File(track.path).existsSync(), isTrue);

    voiceError = null;
    await service.prepare(vameval);
    expect(builds, 2);
  });
}
