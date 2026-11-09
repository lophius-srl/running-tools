import '../domain/beep_schedule.dart';
import '../domain/timed_test.dart';
import 'announcements.dart';
import 'audio_program.dart';

/// Délai entre un signal et l'annonce vocale qui le suit.
const _voiceDelayS = 0.45;

/// Bande-son d'un test par paliers : intro, décompte, bips, annonces.
AudioProgram stagedTestProgram(
  BeepSchedule schedule, {
  required String testName,
  int leadIn = 10,
  int tail = 4,
}) {
  final events = <ProgramEvent>[
    ProgramEvent.speech(
      0.5,
      introAnnouncement(testName, schedule.protocol.startSpeedKmh),
    ),
    for (var s = 3; s >= 1; s--)
      ProgramEvent.cue(leadIn - s.toDouble(), Cue.countdown),
  ];
  for (final event in schedule.events) {
    final at = leadIn + event.timeS;
    switch (event.kind) {
      case BeepKind.start:
        events.add(ProgramEvent.cue(at, Cue.start));
      case BeepKind.marker:
        events.add(ProgramEvent.cue(at, Cue.marker));
      case BeepKind.stageChange:
        events
          ..add(ProgramEvent.cue(at, Cue.change))
          ..add(
            ProgramEvent.speech(
              leadIn + event.timeS + _voiceDelayS,
              stageAnnouncement(
                event.stage,
                schedule.protocol.speedKmh(event.stage),
              ),
            ),
          );
      case BeepKind.end:
        events
          ..add(ProgramEvent.cue(at, Cue.end))
          ..add(ProgramEvent.speech(leadIn + event.timeS + 1, endAnnouncement));
    }
  }
  return AudioProgram(
    durationS: leadIn + schedule.durationS + tail,
    leadInS: leadIn.toDouble(),
    events: events,
  );
}

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

/// Bande-son d'un test chronométré : décompte, départ, annonces, fin.
AudioProgram timedTestProgram(TimedTest test, {int leadIn = 10, int tail = 6}) {
  final events = <ProgramEvent>[
    for (var s = 3; s >= 1; s--)
      ProgramEvent.cue(leadIn - s.toDouble(), Cue.pip),
  ];
  for (final cue in test.cues) {
    final t = leadIn + cue.at.inMilliseconds / 1000;
    final text = timedCueText(test, cue.kind);
    switch (cue.kind) {
      case TimedCueKind.start:
        // L'annonce d'intro précède le départ.
        events
          ..add(ProgramEvent.cue(t, Cue.start))
          ..add(ProgramEvent.speech(0.5, text));
      case TimedCueKind.halfway || TimedCueKind.lastMinute:
        events
          ..add(ProgramEvent.cue(t, Cue.change))
          ..add(ProgramEvent.speech(t + _voiceDelayS, text));
      case TimedCueKind.end:
        events
          ..add(ProgramEvent.cue(t, Cue.end))
          ..add(ProgramEvent.speech(t + 1, text));
    }
  }
  return AudioProgram(
    durationS: leadIn + test.duration.inSeconds + tail * 1.0,
    leadInS: leadIn.toDouble(),
    events: events,
  );
}
