import 'audio_program.dart';

/// Bande-son du métronome : annonce, décompte, puis un tic par pas.
///
/// Chaque tic est calculé depuis le départ (pas de cumul d'arrondis).
AudioProgram metronomeProgram({
  required int stepsPerMinute,
  required Duration duration,
  int leadIn = 5,
}) {
  if (stepsPerMinute <= 0) {
    throw ArgumentError.value(
      stepsPerMinute,
      'stepsPerMinute',
      'doit être > 0',
    );
  }
  final totalS = duration.inMilliseconds / 1000;
  final interval = 60 / stepsPerMinute;
  final beats = (totalS / interval).floor();
  return AudioProgram(
    durationS: leadIn + totalS + 1,
    leadInS: leadIn.toDouble(),
    events: [
      ProgramEvent.speech(0.3, 'Métronome, $stepsPerMinute pas par minute.'),
      for (var s = 3; s >= 1; s--)
        ProgramEvent.cue(leadIn - s.toDouble(), Cue.pip),
      for (var k = 0; k < beats; k++)
        ProgramEvent.cue(leadIn + k * interval, Cue.tick),
    ],
  );
}
