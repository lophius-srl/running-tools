import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/multi_timer.dart';

Duration s(double seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  late MultiTimer timer;

  setUp(() => timer = MultiTimer(['Léa', 'Tom', 'Sam'], targetLaps: 3));

  test('tours, temps au tour, temps cumulé, meilleur tour', () {
    timer
      ..tap(0, s(80))
      ..tap(0, s(162))
      ..tap(0, s(241.5));
    final lea = timer.runners[0];
    expect(lea.laps, 3);
    expect(lea.lapTimes, [s(80), s(82), s(79.5)]);
    expect(lea.passages.last, s(241.5));
    expect(lea.bestLap, s(79.5));
    expect(lea.isFinished(3), isTrue);
  });

  test('un coureur arrivé ne compte plus de tours', () {
    for (final t in <double>[80, 160, 240]) {
      timer.tap(0, s(t));
    }
    expect(timer.tap(0, s(300)), isFalse);
    expect(timer.runners[0].laps, 3);
  });

  test('temps qui recule refusé (double tap)', () {
    timer.tap(1, s(90));
    expect(timer.tap(1, s(90)), isFalse);
    expect(timer.runners[1].laps, 1);
  });

  test('annulation du dernier tap, tous coureurs confondus', () {
    timer
      ..tap(0, s(80))
      ..tap(1, s(85));
    expect(timer.lastTap, (runner: 1, lap: 1));
    expect(timer.undo(), isTrue);
    expect(timer.runners[1].laps, 0);
    expect(timer.lastTap, (runner: 0, lap: 1));
    expect(timer.undo(), isTrue);
    expect(timer.undo(), isFalse);
  });

  test('classement et écarts au premier au même tour', () {
    timer
      ..tap(0, s(80))
      ..tap(1, s(83))
      ..tap(0, s(160))
      ..tap(1, s(168))
      ..tap(2, s(95));
    final standings = timer.standings();
    expect(standings.map((x) => x.runner.name), ['Léa', 'Tom', 'Sam']);
    expect(standings[0].gap, Duration.zero);
    expect(standings[1].gap, s(8)); // 168 − 160 au 2e tour
    expect(standings[2].gap, s(15)); // 95 − 80 au 1er tour
  });

  test('coureur sans tour : pas d\'écart', () {
    timer.tap(0, s(80));
    expect(timer.standings().last.gap, isNull);
  });

  test('tous arrivés', () {
    for (var r = 0; r < 3; r++) {
      for (var lap = 1; lap <= 3; lap++) {
        timer.tap(r, s(80.0 * lap + r));
      }
    }
    expect(timer.allFinished, isTrue);
  });

  test('export texte', () {
    timer
      ..tap(0, s(80))
      ..tap(1, s(83.4));
    expect(
      timer.exportText(title: 'Club 9/11', lapLengthM: 400),
      'Club 9/11\n'
      '1. Léa : 1 tour(s), 1:20,0\n'
      '   Tours : 1:20,0\n'
      '2. Tom : 1 tour(s), 1:23,4 (+0:03,4)\n'
      '   Tours : 1:23,4\n'
      '3. Sam : 0 tour(s), —\n'
      'Tour de 400,00 m',
    );
  });

  test('distance cible → nombre de tours', () {
    expect(lapsForDistance(1200, 400), 3);
    expect(lapsForDistance(1000, 400), 3);
    expect(lapsForDistance(1221, 407.04), 3);
    expect(() => lapsForDistance(0, 400), throwsArgumentError);
  });

  test('paramètres invalides refusés', () {
    expect(() => MultiTimer([], targetLaps: 3), throwsArgumentError);
    expect(() => MultiTimer(['A'], targetLaps: 0), throwsArgumentError);
  });
}
