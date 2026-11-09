import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/track_service.dart';

void main() {
  late Directory dir;
  late int builds;
  String? voiceError;

  Future<String?> fakeBuild(
    AudioProgram program, {
    required Directory workDir,
    required String outputPath,
    int sampleRate = 22050,
    void Function(String step)? onProgress,
  }) async {
    builds++;
    File(outputPath).writeAsStringSync('wav');
    return voiceError;
  }

  AudioProgram program(double markerAt) => AudioProgram(
    durationS: 30,
    leadInS: 10,
    events: [ProgramEvent.cue(markerAt, Cue.marker)],
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tracks');
    builds = 0;
    voiceError = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<String> trackFiles() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList();

  test('même programme : piste réutilisée', () async {
    final service = CachedTrackService(dir, build: fakeBuild);
    final first = await service.prepare(program(12));
    final second = await service.prepare(program(12));
    expect(builds, 1);
    expect(second.path, first.path);
    expect(second.activityTimeAt(const Duration(seconds: 15)), 5);
  });

  test('autre programme : nouvelle piste, l\'ancienne est supprimée', () async {
    final service = CachedTrackService(dir, build: fakeBuild);
    await service.prepare(program(12));
    await service.prepare(program(13));
    expect(builds, 2);
    expect(trackFiles(), hasLength(1));
  });

  test('voix en échec : piste jouable mais pas mise en cache', () async {
    voiceError = 'tts';
    final service = CachedTrackService(dir, build: fakeBuild);
    final track = await service.prepare(program(12));
    expect(track.voiceError, 'tts');
    expect(File(track.path).existsSync(), isTrue);

    voiceError = null;
    await service.prepare(program(12));
    expect(builds, 2);
  });
}
