import 'track_lanes.dart';
import 'workout.dart';

/// Une étape chronologique d'une séance planifiée.
sealed class PlanStep {
  const PlanStep({required this.start, required this.duration});

  /// Début de l'étape depuis le départ de la séance.
  final Duration start;
  final Duration duration;

  Duration get end => start + duration;
}

/// Une répétition, avec ses cibles calculées.
class EffortStep extends PlanStep {
  const EffortStep({
    required super.start,
    required super.duration,
    required this.index,
    required this.total,
    required this.effort,
    required this.speedKmh,
    required this.distanceM,
    required this.markerSplits,
    required this.lapTime,
  });

  /// Numéro de la répétition (1 à [total]).
  final int index;
  final int total;
  final Effort effort;

  /// Vitesse cible ; `null` sans % VMA (côtes).
  final double? speedKmh;

  /// Distance (comptée en couloir 1) : donnée, ou estimée pour un effort au
  /// temps ; `null` si inconnue.
  final double? distanceM;

  /// Temps cumulés au passage de chaque repère (efforts en distance).
  final List<Duration> markerSplits;

  /// Temps pour un tour de piste dans le couloir choisi ; `null` sans allure.
  final Duration? lapTime;
}

/// Une récupération.
class RecoveryStep extends PlanStep {
  const RecoveryStep({
    required super.start,
    required super.duration,
    required this.recovery,
  });

  final Recovery recovery;
}

/// Séance appliquée à une VMA, un espacement de repères et un couloir.
class WorkoutPlan {
  WorkoutPlan._(this.workout, this.steps);

  factory WorkoutPlan.compute(
    Workout workout, {
    required double vmaKmh,
    required double markerSpacingM,
    int lane = 1,
    TrackGeometry track = TrackGeometry.standard,
  }) {
    if (!(vmaKmh > 0)) {
      throw ArgumentError.value(vmaKmh, 'vmaKmh', 'doit être > 0');
    }
    if (!(markerSpacingM > 0)) {
      throw ArgumentError.value(
        markerSpacingM,
        'markerSpacingM',
        'doit être > 0',
      );
    }
    final steps = <PlanStep>[];
    var t = Duration.zero;
    var index = 0;
    final total = workout.effortCount;
    for (final set in workout.sets) {
      for (var rep = 0; rep < set.reps; rep++) {
        index++;
        final effort = set.effort;
        final speed = effort.percentVma == null
            ? null
            : vmaKmh * effort.percentVma! / 100;
        final Duration duration;
        double? distance;
        var markers = <Duration>[];
        if (effort.distanceM case final d?) {
          distance = d;
          // Sans allure cible, une répétition en distance n'a pas de durée.
          duration = speed == null
              ? Duration.zero
              : track.splitFor(d, lane, speed);
          if (speed != null) {
            markers = [
              for (var m = markerSpacingM; m <= d + 1e-9; m += markerSpacingM)
                track.splitFor(m, lane, speed),
            ];
          }
        } else {
          duration = effort.duration!;
          if (speed != null) {
            distance =
                speed /
                3.6 *
                (duration.inMicroseconds / 1e6) /
                track.laneFactor(lane);
          }
        }
        steps.add(
          EffortStep(
            start: t,
            duration: duration,
            index: index,
            total: total,
            effort: effort,
            speedKmh: speed,
            distanceM: distance,
            markerSplits: markers,
            lapTime: speed == null ? null : track.splitFor(400, lane, speed),
          ),
        );
        t += duration;
        final recovery = set.recovery;
        if (recovery != null && index < total) {
          final rest = _recoveryDuration(recovery, vmaKmh, lane, track);
          steps.add(RecoveryStep(start: t, duration: rest, recovery: recovery));
          t += rest;
        }
      }
    }
    return WorkoutPlan._(workout, List.unmodifiable(steps));
  }

  final Workout workout;
  final List<PlanStep> steps;

  Iterable<EffortStep> get efforts => steps.whereType<EffortStep>();

  Duration get totalDuration => steps.isEmpty ? Duration.zero : steps.last.end;

  /// Étape en cours à [elapsed] depuis le départ ; `null` avant ou après.
  PlanStep? stepAt(Duration elapsed) {
    for (final step in steps) {
      if (elapsed >= step.start && elapsed < step.end) return step;
    }
    return null;
  }

  static Duration _recoveryDuration(
    Recovery recovery,
    double vmaKmh,
    int lane,
    TrackGeometry track,
  ) => switch (recovery) {
    Recovery(duration: final d?) => d,
    Recovery(distanceM: final d?) => track.splitFor(
      d,
      lane,
      vmaKmh * Recovery.joggingPercentVma / 100,
    ),
    _ => Duration.zero,
  };
}
