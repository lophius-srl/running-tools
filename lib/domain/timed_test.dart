import 'test_results.dart';

/// Tests à durée fixe : on court le plus loin possible, puis on saisit la
/// distance.
enum TimedTest {
  cooper('Cooper', Duration(minutes: 12)),
  halfCooper('Demi-Cooper', Duration(minutes: 6));

  const TimedTest(this.label, this.duration);

  final String label;
  final Duration duration;

  TestResult result(double distanceM) => switch (this) {
    cooper => cooperResult(distanceM),
    halfCooper => halfCooperResult(distanceM),
  };

  /// Annonces du chrono, dans l'ordre.
  List<TimedCue> get cues => [
    const TimedCue(TimedCueKind.start, Duration.zero),
    TimedCue(TimedCueKind.halfway, duration ~/ 2),
    TimedCue(TimedCueKind.lastMinute, duration - const Duration(minutes: 1)),
    TimedCue(TimedCueKind.end, duration),
  ];
}

enum TimedCueKind { start, halfway, lastMinute, end }

/// Une annonce du chrono, à [at] après le départ.
class TimedCue {
  const TimedCue(this.kind, this.at);

  final TimedCueKind kind;
  final Duration at;
}
