import '../domain/fartlek.dart';
import '../domain/training_paces.dart';
import 'audio_program.dart';

/// « 45 secondes », « 1 minute 30 », « 2 minutes ».
String spokenDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m == 0) return '$s secondes';
  final minutes = m == 1 ? '1 minute' : '$m minutes';
  return s == 0 ? minutes : '$minutes $s';
}

/// Annonce d'une accélération.
String burstAnnouncement(FartlekBurst burst, {double? speedKmh}) {
  final how = spokenDuration(burst.duration);
  if (speedKmh != null) {
    final pace = paceForSpeed(speedKmh);
    final seconds = pace.inSeconds % 60;
    final perKm =
        '${pace.inMinutes} minutes${seconds == 0 ? '' : ' $seconds'} '
        'au kilomètre';
    return 'Accélère $how, à $perKm !';
  }
  return switch (burst.feel) {
    FartlekFeel.veryFast => 'Très vite, $how !',
    _ => 'Vite, $how !',
  };
}

const recoverAnnouncement = 'Récupère.';
const fartlekEndAnnouncement = 'Fin de la séance. Bravo !';

/// Bande-son du fartlek : rien d'annoncé à l'avance, la surprise est réelle.
AudioProgram fartlekProgram(
  FartlekPlan plan, {
  double? vmaKmh,
  int leadIn = 5,
  int tail = 4,
}) {
  double at(Duration d) => leadIn + d.inMilliseconds / 1000;
  final s = plan.settings;
  final speed = s.percentVma != null && vmaKmh != null
      ? vmaKmh * s.percentVma! / 100
      : null;
  final events = <ProgramEvent>[
    ProgramEvent.speech(
      0.3,
      'Fartlek surprise, ${spokenDuration(s.total)}. '
      'Échauffement ${spokenDuration(s.warmup)}.',
    ),
    for (var k = 3; k >= 1; k--)
      ProgramEvent.cue(leadIn - k.toDouble(), Cue.pip),
    ProgramEvent.cue(at(Duration.zero), Cue.start),
    ProgramEvent.speech(
      at(s.warmup),
      'Fin de l’échauffement. Reste attentif !',
    ),
  ];
  for (final b in plan.bursts) {
    events
      ..add(ProgramEvent.cue(at(b.start), Cue.start))
      ..add(
        ProgramEvent.speech(
          at(b.start) + 0.45,
          burstAnnouncement(b, speedKmh: speed),
        ),
      );
    // Décompte sonore avant la fin de l'accélération.
    for (var k = 3; k >= 1; k--) {
      events.add(ProgramEvent.cue(at(b.end) - k, Cue.pip));
    }
    events
      ..add(ProgramEvent.cue(at(b.end), Cue.change))
      ..add(ProgramEvent.speech(at(b.end) + 0.45, recoverAnnouncement));
  }
  events
    ..add(
      ProgramEvent.speech(at(s.total - s.cooldown) + 1.5, 'Retour au calme.'),
    )
    ..add(ProgramEvent.cue(at(s.total), Cue.end))
    ..add(ProgramEvent.speech(at(s.total) + 1, fartlekEndAnnouncement));
  return AudioProgram(
    durationS: at(s.total) + tail,
    leadInS: leadIn.toDouble(),
    events: events,
  );
}
