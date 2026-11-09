import '../domain/workout.dart';
import '../domain/workout_plan.dart';
import 'announcements.dart';
import 'audio_program.dart';

/// Annonce d'une répétition, lue juste avant le départ.
String effortAnnouncement(EffortStep step) {
  final effort = step.effort;
  final what = effort.isDistance
      ? '${formatKmh(effort.distanceM!)} mètres'
      : _spokenDuration(effort.duration!);
  final pace = effort.percentVma == null
      ? ''
      : ' à ${formatKmh(effort.percentVma!)} pour cent';
  return 'Répétition ${step.index} sur ${step.total}, $what$pace.';
}

String recoveryAnnouncement(RecoveryStep step) =>
    'Récupération, ${_spokenDuration(step.duration)}.';

const sessionEndAnnouncement = 'Fin de la séance. Bravo !';

/// Lièvre : un bip à chaque repère pendant les répétitions en distance.
/// Chrono : seulement les signaux de début et de fin.
enum WorkoutAudioMode { chrono, pacer }

const recoveryCountdownAnnouncement = 'Encore 30 secondes.';

/// Bande-son d'une séance : décompte et signal au début de chaque
/// répétition, signal à la fin, annonces de répétition et de récupération ;
/// en mode [WorkoutAudioMode.pacer], un bip à chaque repère.
AudioProgram workoutProgram(
  WorkoutPlan plan, {
  WorkoutAudioMode mode = WorkoutAudioMode.chrono,
  String Function(EffortStep step) announce = effortAnnouncement,
  int leadIn = 10,
  int tail = 4,
}) {
  double at(Duration d) => leadIn + d.inMilliseconds / 1000;
  final events = <ProgramEvent>[];
  final efforts = plan.efforts.toList();
  for (final step in plan.steps) {
    switch (step) {
      case EffortStep():
        final start = at(step.start);
        // Annonce 6 s avant le départ (pendant l'intro ou la récup).
        events.add(ProgramEvent.speech(start - 6, announce(step)));
        for (var s = 3; s >= 1; s--) {
          events.add(ProgramEvent.cue(start - s, Cue.pip));
        }
        events.add(ProgramEvent.cue(start, Cue.start));
        if (mode == WorkoutAudioMode.pacer) {
          for (final split in step.markerSplits) {
            // Le dernier repère tombe sur le signal de fin : pas de doublon.
            if (step.duration - split < const Duration(milliseconds: 300)) {
              continue;
            }
            events.add(ProgramEvent.cue(at(step.start + split), Cue.marker));
          }
        }
        final isLast = identical(step, efforts.last);
        events.add(
          ProgramEvent.cue(at(step.end), isLast ? Cue.end : Cue.change),
        );
        if (isLast) {
          events.add(
            ProgramEvent.speech(at(step.end) + 1, sessionEndAnnouncement),
          );
        }
      case RecoveryStep():
        // Laisse la place à l'annonce de la répétition suivante.
        if (step.duration >= const Duration(seconds: 12)) {
          events.add(
            ProgramEvent.speech(
              at(step.start) + 0.45,
              recoveryAnnouncement(step),
            ),
          );
        }
        if (step.duration >= const Duration(seconds: 50)) {
          events.add(
            ProgramEvent.speech(
              at(step.end) - 30,
              recoveryCountdownAnnouncement,
            ),
          );
        }
    }
  }
  return AudioProgram(
    durationS: at(plan.totalDuration) + tail,
    leadInS: leadIn.toDouble(),
    events: events,
  );
}

String _spokenDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m == 0) return '$s secondes';
  final minutes = m == 1 ? '1 minute' : '$m minutes';
  return s == 0 ? minutes : '$minutes $s';
}

/// Résumé lisible d'une série : « 8 × 400 m à 100 % ».
String describeSet(WorkoutSet set) {
  final e = set.effort;
  final what = e.isDistance
      ? '${formatKmh(e.distanceM!)} m'
      : _shortDuration(e.duration!);
  final pace = e.percentVma == null ? '' : ' à ${formatKmh(e.percentVma!)} %';
  final reps = set.reps > 1 ? '${set.reps} × ' : '';
  return '$reps$what$pace';
}

String _shortDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m == 0) return '$s s';
  return s == 0 ? '$m min' : '$m min ${s.toString().padLeft(2, '0')}';
}
