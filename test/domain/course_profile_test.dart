import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/course_profile.dart';

/// GPX plein nord, un point tous les 20 m, altitude donnée par [ele].
String gpx(double lengthM, double Function(double d) ele, {Random? noise}) {
  final points = [
    for (var d = 0.0; d <= lengthM; d += 20)
      '<trkpt lat="${45 + d / 6371000 * 180 / pi}" lon="4">'
          '<ele>${ele(d) + (noise == null ? 0 : (noise.nextDouble() - 0.5) * 4)}</ele></trkpt>',
  ];
  return '<gpx><trk><name>Trail des crêtes</name><trkseg>${points.join()}'
      '</trkseg></trk></gpx>';
}

/// 2 km plat, 1 km à +6 %, 1 km à −6 %, 1 km plat.
double hill(double d) {
  if (d <= 2000) return 200;
  if (d <= 3000) return 200 + (d - 2000) * 0.06;
  if (d <= 4000) return 260 - (d - 3000) * 0.06;
  return 200;
}

void main() {
  test('GPX sans temps : nom, distance, profil tous les 10 m', () {
    final p = parseGpxCourse(gpx(5000, hill));
    expect(p.name, 'Trail des crêtes');
    expect(p.distanceM, closeTo(5000, 10));
    expect(p.elevations.length, closeTo(501, 1));
  });

  test('dénivelé : bruit gommé par le lissage', () {
    final p = parseGpxCourse(gpx(5000, hill, noise: Random(3)));
    final c = p.climb();
    expect(c.gain, closeTo(60, 6));
    expect(c.loss, closeTo(60, 6));
  });

  test('itinéraire (rtept) accepté ; sans altitude refusé', () {
    final route = gpx(1000, (_) => 100)
        .replaceAll('trkpt', 'rtept')
        .replaceAll('<trk>', '<rte>')
        .replaceAll('</trk>', '</rte>');
    expect(parseGpxCourse(route).distanceM, closeTo(1000, 10));
    expect(
      () => parseGpxCourse(
        '<gpx><trk><trkseg><trkpt lat="45" lon="4"/>'
        '</trkseg></trk></gpx>',
      ),
      throwsFormatException,
    );
    expect(() => parseGpxCourse('<<'), throwsFormatException);
  });

  test('découpage : plat, montée, descente, plat', () {
    final p = parseGpxCourse(gpx(5000, hill));
    final sections = splitSections(p);
    expect(sections.map((s) => s.kind), [
      SectionKind.flat,
      SectionKind.climb,
      SectionKind.descent,
      SectionKind.flat,
    ]);
    expect(sections[1].startM, closeTo(2000, 100));
    expect(sections[2].startM, closeTo(3000, 100));
    expect(sections.last.endM, p.distanceM);
    // Sections contiguës.
    for (var i = 1; i < sections.length; i++) {
      expect(sections[i].from, sections[i - 1].to);
    }
  });

  test('petite bosse de 100 m : absorbée dans le plat', () {
    double bump(double d) =>
        d > 1000 && d < 1100 ? 200 + (d - 1000) * 0.05 : 200;
    final sections = splitSections(parseGpxCourse(gpx(3000, bump)));
    expect(sections.single.kind, SectionKind.flat);
  });

  test('moyenne glissante', () {
    expect(smooth([0, 0, 9, 0, 0], 3), [0, 3, 3, 3, 0]);
  });
}
