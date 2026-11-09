import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../domain/timed_test.dart';
import 'pcm.dart';
import 'voice_synthesizer.dart';
import 'wav.dart';

/// Textes des annonces d'un test chronométré.
String timedCueText(TimedTest test, TimedCueKind kind) => switch (kind) {
  TimedCueKind.start =>
    'Test ${test.label}, ${test.duration.inMinutes} minutes. '
        'Départ dans 3 secondes.',
  TimedCueKind.halfway =>
    'Mi-temps. Encore ${test.duration.inMinutes ~/ 2} minutes.',
  TimedCueKind.lastMinute => 'Dernière minute.',
  TimedCueKind.end => 'Fin du test. Arrêtez-vous et notez votre distance.',
};

/// Rend la piste d'un test chronométré : intro, décompte, départ, annonces.
/// Le départ tombe à [leadIn] secondes dans la piste.
Int16List renderTimedTrack(
  TimedTest test,
  Map<TimedCueKind, Float32List> voices, {
  int sampleRate = 22050,
  int leadIn = 10,
  int tail = 6,
}) {
  int at(double s) => (s * sampleRate).round();
  Duration ms(int n) => Duration(milliseconds: n);
  final track = Int16List(at(leadIn + test.duration.inSeconds + tail * 1.0));
  final pip = tone(sampleRate: sampleRate, frequencyHz: 800, duration: ms(100));
  final start = tone(
    sampleRate: sampleRate,
    frequencyHz: 1200,
    duration: ms(600),
  );
  final signal = sequence([
    tone(sampleRate: sampleRate, frequencyHz: 1500, duration: ms(120)),
    tone(sampleRate: sampleRate, frequencyHz: 1500, duration: ms(120)),
  ], at(0.08));
  final end = sequence([
    for (var i = 0; i < 3; i++)
      tone(sampleRate: sampleRate, frequencyHz: 1200, duration: ms(250)),
  ], at(0.1));

  for (var s = 3; s >= 1; s--) {
    mixInto(track, at(leadIn - s.toDouble()), pip);
  }
  for (final cue in test.cues) {
    final t = leadIn + cue.at.inMilliseconds / 1000;
    final voice = voices[cue.kind];
    switch (cue.kind) {
      case TimedCueKind.start:
        mixInto(track, at(t), start);
        // L'annonce d'intro précède le départ.
        if (voice != null) mixInto(track, at(0.5), voice);
      case TimedCueKind.halfway || TimedCueKind.lastMinute:
        mixInto(track, at(t), signal);
        if (voice != null) mixInto(track, at(t + 0.45), voice);
      case TimedCueKind.end:
        mixInto(track, at(t), end);
        if (voice != null) mixInto(track, at(t + 1), voice);
    }
  }
  return track;
}

/// Synthétise les annonces puis écrit la piste dans [outputPath].
/// Renvoie l'erreur de synthèse vocale éventuelle (piste avec bips seuls).
Future<String?> buildTimedTrack(
  TimedTest test, {
  required Directory workDir,
  required String outputPath,
  int sampleRate = 22050,
  int leadIn = 10,
  void Function(String step)? onProgress,
}) async {
  final voices = <TimedCueKind, Float32List>{};
  String? voiceError;
  try {
    final synth = VoiceSynthesizer(workDir: workDir, sampleRate: sampleRate);
    for (final kind in TimedCueKind.values) {
      onProgress?.call('Synthèse vocale : ${kind.index + 1}/4');
      voices[kind] = await synth.synthesize(timedCueText(test, kind));
    }
  } catch (e) {
    voiceError = e.toString();
    voices.clear();
  }
  onProgress?.call('Mixage de la piste…');
  await Isolate.run(() {
    writeWavFile(
      outputPath,
      renderTimedTrack(test, voices, sampleRate: sampleRate, leadIn: leadIn),
      sampleRate,
    );
  });
  return voiceError;
}
