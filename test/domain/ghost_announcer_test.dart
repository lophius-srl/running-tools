import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/ghost.dart';
import 'package:running_tools/domain/ghost_announcer.dart';

GhostGap gap(double seconds, double meters) =>
    GhostGap(seconds: seconds, meters: meters);

void main() {
  test('écart décrit en français', () {
    expect(describeGap(gap(12.4, 40)), 'Tu as 12 secondes d’avance.');
    expect(describeGap(gap(-1, -3)), 'Tu as 1 seconde de retard.');
    expect(describeGap(gap(0.3, 1)), 'Tu es à hauteur du fantôme.');
    expect(describeGap(gap(-75, -250)), 'Tu as 1 minute 15 de retard.');
    expect(describeGap(gap(120, 400)), 'Tu as 2 minutes d’avance.');
  });

  test('annonce à chaque km', () {
    final a = GhostAnnouncer();
    expect(a.update(timeS: 290, distanceM: 990, gap: gap(3, 4)), isNull);
    expect(
      a.update(timeS: 297, distanceM: 1001, gap: gap(3, 4)),
      '1 kilomètre. Tu as 3 secondes d’avance.',
    );
    expect(a.update(timeS: 300, distanceM: 1010, gap: gap(3, 4)), isNull);
    expect(
      a.update(timeS: 600, distanceM: 2000, gap: gap(-2, -6)),
      '2 kilomètres. Tu as 2 secondes de retard.',
    );
  });

  test('annonce toutes les 2 minutes', () {
    final a = GhostAnnouncer(every: GhostAnnounceEvery.twoMinutes);
    expect(a.update(timeS: 119, distanceM: 390, gap: gap(0, 0)), isNull);
    expect(
      a.update(timeS: 120, distanceM: 400, gap: gap(0, 0)),
      '2 minutes. Tu es à hauteur du fantôme.',
    );
  });

  test('changement de leader, sans annonces en boucle au coude à coude', () {
    final a = GhostAnnouncer();
    // Je prends 12 m d'avance : premier leader, pas d'annonce.
    expect(a.update(timeS: 60, distanceM: 200, gap: gap(4, 12)), isNull);
    // Coude à coude, sous le seuil : rien.
    expect(a.update(timeS: 70, distanceM: 230, gap: gap(-1, -4)), isNull);
    expect(a.update(timeS: 80, distanceM: 260, gap: gap(1, 3)), isNull);
    // Le fantôme passe vraiment devant.
    expect(
      a.update(timeS: 90, distanceM: 290, gap: gap(-5, -15)),
      'Le fantôme repasse devant, 15 mètres.',
    );
    expect(
      a.update(timeS: 150, distanceM: 500, gap: gap(4, 11)),
      'Tu dépasses ton fantôme !',
    );
  });

  test('leader et km en même temps : les deux, leader d’abord', () {
    final a = GhostAnnouncer();
    a.update(timeS: 200, distanceM: 700, gap: gap(-4, -12));
    expect(
      a.update(timeS: 290, distanceM: 1000, gap: gap(4, 12)),
      'Tu dépasses ton fantôme ! 1 kilomètre. Tu as 4 secondes d’avance.',
    );
  });

  test('courbe d’écart : un point tous les 100 m', () {
    final c = GapCurve();
    for (var d = 0; d <= 350; d += 7) {
      c.add(d.toDouble(), gap(d / 100, d / 30));
    }
    expect(c.points.map((p) => p.$1), [100, 200, 300]);
    expect(c.points.first.$2, closeTo(1.05, 1e-9));
  });
}
