import 'dart:typed_data';

import 'audio_program.dart';
import 'pcm.dart';

/// Fréquence d'échantillonnage des bandes-son.
const trackSampleRate = 22050;

/// Rend un [AudioProgram] en échantillons 16 bits, à l'échantillon près.
class ProgramRenderer {
  ProgramRenderer({this.sampleRate = trackSampleRate});

  final int sampleRate;

  int sampleAt(double trackTimeS) => (trackTimeS * sampleRate).round();

  /// [voices] : annonces déjà décodées à [sampleRate], par texte. Une annonce
  /// absente est ignorée (piste avec bips seuls).
  Int16List render(AudioProgram program, Map<String, Float32List> voices) {
    final track = Int16List(sampleAt(program.durationS));
    final sounds = _sounds();
    for (final event in program.events) {
      final at = sampleAt(event.atS);
      if (event.cue case final cue?) mixInto(track, at, sounds[cue]!);
      if (voices[event.speech] case final voice?) mixInto(track, at, voice);
    }
    return track;
  }

  Map<Cue, Float32List> _sounds() {
    Duration ms(int n) => Duration(milliseconds: n);
    Float32List beep(double hz, int durationMs, {double amplitude = 0.8}) =>
        tone(
          sampleRate: sampleRate,
          frequencyHz: hz,
          duration: ms(durationMs),
          amplitude: amplitude,
        );
    return {
      Cue.marker: beep(1000, 150),
      Cue.change: sequence([beep(1500, 120), beep(1500, 120)], sampleAt(0.08)),
      Cue.countdown: beep(800, 100, amplitude: 0.6),
      Cue.pip: beep(800, 100),
      Cue.start: beep(1200, 600),
      Cue.tick: beep(2000, 40, amplitude: 0.7),
      Cue.end: sequence([
        for (var i = 0; i < 3; i++) beep(1200, 250),
      ], sampleAt(0.1)),
    };
  }
}
