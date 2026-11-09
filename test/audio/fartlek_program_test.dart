import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/fartlek_program.dart';
import 'package:running_tools/domain/fartlek.dart';

void main() {
  final plan = FartlekPlan.generate(const FartlekSettings(), 42);
  final program = fartlekProgram(plan);
  double at(Duration d) => 5 + d.inMilliseconds / 1000;

  List<double> times(Cue cue) => [
    for (final e in program.events)
      if (e.cue == cue) e.atS,
  ];

  test('signal au début de chaque accélération, double bip à la fin', () {
    final starts = times(Cue.start);
    // Départ de la séance + une par accélération.
    expect(starts, hasLength(plan.bursts.length + 1));
    expect(starts.skip(1), [for (final b in plan.bursts) at(b.start)]);
    expect(times(Cue.change), [for (final b in plan.bursts) at(b.end)]);
  });

  test('décompte de 3 bips avant la fin de chaque accélération', () {
    final pips = times(Cue.pip).skip(3).toList(); // après le décompte initial
    expect(pips, hasLength(3 * plan.bursts.length));
    final b = plan.bursts.first;
    expect(pips.take(3), [at(b.end) - 3, at(b.end) - 2, at(b.end) - 1]);
  });

  test('annonces : ressenti, « Récupère », fin', () {
    final b = plan.bursts.first;
    final text = burstAnnouncement(b);
    expect(text, anyOf(startsWith('Vite, '), startsWith('Très vite, ')));
    expect(program.speeches, containsAll([text, recoverAnnouncement]));
    expect(program.speeches, contains(fartlekEndAnnouncement));
    expect(times(Cue.end).single, at(plan.total));
  });

  test('en % VMA : allure annoncée', () {
    const burst = FartlekBurst(
      start: Duration(minutes: 12),
      duration: Duration(seconds: 45),
    );
    expect(
      burstAnnouncement(burst, speedKmh: 15),
      'Accélère 45 secondes, à 4 minutes au kilomètre !',
    );
    expect(
      burstAnnouncement(
        const FartlekBurst(
          start: Duration.zero,
          duration: Duration(seconds: 90),
        ),
        speedKmh: 14,
      ),
      'Accélère 1 minute 30, à 4 minutes 17 au kilomètre !',
    );
  });

  test('durée en toutes lettres', () {
    expect(spokenDuration(const Duration(seconds: 20)), '20 secondes');
    expect(spokenDuration(const Duration(minutes: 2)), '2 minutes');
    expect(spokenDuration(const Duration(seconds: 65)), '1 minute 5');
  });
}
