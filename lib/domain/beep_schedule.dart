import 'dart:math';

import 'stage_protocol.dart';

enum BeepKind { start, marker, stageChange, end }

/// Un signal sonore du test, à [timeS] secondes après le départ.
class BeepEvent {
  const BeepEvent({
    required this.timeS,
    required this.kind,
    required this.stage,
    required this.distanceM,
  });

  final double timeS;
  final BeepKind kind;

  /// Palier en cours au moment du signal (pour [BeepKind.stageChange] : le
  /// nouveau palier).
  final int stage;
  final double distanceM;
}

/// Où en est le coureur à un instant donné.
class StagePosition {
  const StagePosition({
    required this.stage,
    required this.speedKmh,
    required this.fractionOfStage,
    required this.distanceM,
  });

  final int stage;
  final double speedKmh;

  /// Part du palier en cours déjà courue, entre 0 et 1.
  final double fractionOfStage;
  final double distanceM;
}

/// Planning complet des bips d'un test par paliers.
///
/// Vitesse constante dans chaque palier ; un bip chaque fois que la distance
/// cumulée franchit un multiple de l'espacement. Un changement de palier peut
/// donc tomber au milieu d'un intervalle entre deux repères.
class BeepSchedule {
  BeepSchedule._(this.protocol, this.durationS, this.events);

  factory BeepSchedule.generate(
    StageProtocol protocol, {
    required Duration duration,
  }) {
    const epsilon = 1e-9;
    final totalS = duration.inMicroseconds / 1e6;
    final stageS = protocol.stageSeconds;
    final spacing = protocol.markerSpacingM;
    final events = <BeepEvent>[
      const BeepEvent(timeS: 0, kind: BeepKind.start, stage: 1, distanceM: 0),
    ];

    var nextMarker = 1;
    for (var stage = 1; (stage - 1) * stageS < totalS - epsilon; stage++) {
      final stageStartS = (stage - 1) * stageS;
      final stageEndS = min(stage * stageS, totalS);
      final startDistance = protocol.distanceAtStageStart(stage);
      final speed = protocol.speedMs(stage);
      if (stage > 1) {
        events.add(
          BeepEvent(
            timeS: stageStartS,
            kind: BeepKind.stageChange,
            stage: stage,
            distanceM: startDistance,
          ),
        );
      }
      final endDistance = startDistance + speed * (stageEndS - stageStartS);
      while (nextMarker * spacing <= endDistance + epsilon) {
        final markerDistance = nextMarker * spacing;
        events.add(
          BeepEvent(
            timeS: stageStartS + (markerDistance - startDistance) / speed,
            kind: BeepKind.marker,
            stage: stage,
            distanceM: markerDistance,
          ),
        );
        nextMarker++;
      }
    }

    final end = _position(protocol, totalS, totalS);
    events
      ..add(
        BeepEvent(
          timeS: totalS,
          kind: BeepKind.end,
          stage: end.stage,
          distanceM: end.distanceM,
        ),
      )
      ..sort((a, b) => a.timeS.compareTo(b.timeS));
    return BeepSchedule._(protocol, totalS, List.unmodifiable(events));
  }

  final StageProtocol protocol;
  final double durationS;
  final List<BeepEvent> events;

  int get stageCount => positionAt(durationS).stage;

  StagePosition positionAt(double timeS) =>
      _position(protocol, durationS, timeS);

  static StagePosition _position(
    StageProtocol protocol,
    double durationS,
    double timeS,
  ) {
    final stageS = protocol.stageSeconds;
    final t = timeS.clamp(0, durationS).toDouble();
    // Un instant pile en fin de test appartient encore au dernier palier.
    var stage = (t / stageS).floor() + 1;
    if (t >= durationS && t > 0 && t % stageS == 0) stage--;
    final intoStageS = t - (stage - 1) * stageS;
    return StagePosition(
      stage: stage,
      speedKmh: protocol.speedKmh(stage),
      fractionOfStage: intoStageS / stageS,
      distanceM:
          protocol.distanceAtStageStart(stage) +
          protocol.speedMs(stage) * intoStageS,
    );
  }
}
