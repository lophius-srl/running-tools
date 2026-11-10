import '../domain/orthostatic.dart';
import 'audio_program.dart';

/// Fenêtres de comptage manuel (15 s) : couché, pic debout, stabilisé.
List<Duration> manualCountStarts(OrthostaticProtocol p) => [
  p.lying - const Duration(seconds: 20),
  p.lying + const Duration(seconds: 5),
  p.total - const Duration(seconds: 20),
];

const manualCountLength = Duration(seconds: 15);

/// Protocole guidé à la voix. En mode manuel, « Top, compte ! » / « Stop »
/// encadrent chaque comptage de 15 s.
AudioProgram orthostaticProgram(
  OrthostaticProtocol protocol, {
  required bool manual,
  int leadIn = 2,
  int tail = 4,
}) {
  double at(Duration d) => leadIn + d.inMilliseconds / 1000;
  final events = <ProgramEvent>[
    const ProgramEvent.speech(
      0.3,
      'Test orthostatique. Allonge-toi sur le dos, détends-toi et reste '
      'immobile.',
    ),
  ];
  if (manual) {
    for (final start in manualCountStarts(protocol)) {
      events
        ..add(ProgramEvent.speech(at(start) - 5, 'Prépare-toi à compter.'))
        ..add(ProgramEvent.cue(at(start), Cue.pip))
        ..add(ProgramEvent.speech(at(start) + 0.3, 'Top, compte !'))
        ..add(ProgramEvent.cue(at(start + manualCountLength), Cue.change))
        ..add(
          ProgramEvent.speech(
            at(start + manualCountLength) + 0.45,
            'Stop. Retiens ce nombre.',
          ),
        );
    }
  } else {
    events.add(
      ProgramEvent.speech(
        at(protocol.lying - protocol.window),
        'Mesure de la fréquence couchée.',
      ),
    );
  }
  events
    ..add(ProgramEvent.cue(at(protocol.standUpAt), Cue.start))
    ..add(
      ProgramEvent.speech(
        at(protocol.standUpAt) + 0.7,
        'Lève-toi maintenant, et reste debout immobile.',
      ),
    )
    ..add(ProgramEvent.cue(at(protocol.total), Cue.end))
    ..add(ProgramEvent.speech(at(protocol.total) + 1, 'Test terminé.'));
  return AudioProgram(
    durationS: at(protocol.total) + tail,
    leadInS: leadIn.toDouble(),
    events: events,
  );
}
