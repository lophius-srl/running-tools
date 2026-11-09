import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chronomètre de course (remplacé par une horloge pilotée dans les tests).
abstract interface class RaceClock {
  void start();
  Duration get elapsed;
}

class StopwatchRaceClock implements RaceClock {
  final _watch = Stopwatch();

  @override
  void start() => _watch
    ..reset()
    ..start();

  @override
  Duration get elapsed => _watch.elapsed;
}

/// Crée une horloge par chronométrage.
final raceClockFactoryProvider = Provider<RaceClock Function()>(
  (ref) => StopwatchRaceClock.new,
);
