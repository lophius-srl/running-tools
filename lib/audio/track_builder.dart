import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../domain/beep_schedule.dart';
import 'announcements.dart';
import 'track_renderer.dart';
import 'voice_synthesizer.dart';
import 'wav.dart';

/// Résultat de la génération d'une piste.
class BuiltTrack {
  const BuiltTrack({
    required this.path,
    required this.bytes,
    required this.voiceError,
  });

  final String path;
  final int bytes;

  /// Non nul si les annonces vocales ont échoué (piste avec bips seuls).
  final String? voiceError;
}

/// Synthétise les annonces puis rend la piste WAV dans un isolate.
Future<BuiltTrack> buildTrack({
  required BeepSchedule schedule,
  required TrackRenderer renderer,
  required String testName,
  required Directory workDir,
  required String outputPath,
  void Function(String step)? onProgress,
}) async {
  AnnouncementClips clips;
  String? voiceError;
  try {
    clips = await _synthesizeClips(
      schedule,
      testName,
      VoiceSynthesizer(workDir: workDir, sampleRate: renderer.sampleRate),
      onProgress,
    );
  } catch (e) {
    voiceError = e.toString();
    clips = const AnnouncementClips();
  }

  onProgress?.call('Mixage de la piste…');
  final path = outputPath;
  await Isolate.run(() {
    writeWavFile(path, renderer.render(schedule, clips), renderer.sampleRate);
  });
  return BuiltTrack(
    path: path,
    bytes: File(path).lengthSync(),
    voiceError: voiceError,
  );
}

Future<AnnouncementClips> _synthesizeClips(
  BeepSchedule schedule,
  String testName,
  VoiceSynthesizer voice,
  void Function(String step)? onProgress,
) async {
  final protocol = schedule.protocol;
  onProgress?.call('Synthèse vocale : intro');
  final intro = await voice.synthesize(
    introAnnouncement(testName, protocol.startSpeedKmh),
  );
  final stages = <int, Float32List>{};
  for (var stage = 2; stage <= schedule.stageCount; stage++) {
    onProgress?.call('Synthèse vocale : palier $stage/${schedule.stageCount}');
    stages[stage] = await voice.synthesize(
      stageAnnouncement(stage, protocol.speedKmh(stage)),
    );
  }
  final end = await voice.synthesize(endAnnouncement);
  return AnnouncementClips(intro: intro, stages: stages, end: end);
}
