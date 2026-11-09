import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/track_builder.dart';
import 'package:running_tools/audio/track_service.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';
import 'package:running_tools/domain/timed_test.dart';

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

  test('piste chronométrée en cache, et une seule piste gardée', () async {
    var timedBuilds = 0;
    Future<String?> fakeTimed(
      TimedTest test, {
      required Directory workDir,
      required String outputPath,
      int sampleRate = 22050,
      int leadIn = 10,
      void Function(String step)? onProgress,
    }) async {
      timedBuilds++;
      File(outputPath).writeAsStringSync('wav');
      return null;
    }

    final service = CachedTrackService(
      dir,
      build: fakeBuild,
      buildTimed: fakeTimed,
    );
    await service.prepare(vameval);
    final first = await service.prepareTimed(TimedTest.cooper);
    final again = await service.prepareTimed(TimedTest.cooper);
    expect(timedBuilds, 1);
    expect(again.path, first.path);
    expect(again.leadIn, 10);
    expect(trackFiles(), hasLength(1));
  });
}
