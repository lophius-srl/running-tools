import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/gpx.dart';

String gpx(Iterable<String> points, {String name = 'Footing du dimanche'}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>$name</name><trkseg>
${points.join('\n')}
  </trkseg></trk>
</gpx>''';

String pt(int second, double northM) {
  final lat = 45.75 + northM / 6371000 * 180 / pi;
  final time = DateTime.utc(2026, 11, 2, 8).add(Duration(seconds: second));
  return '<trkpt lat="$lat" lon="4.85"><ele>170</ele>'
      '<time>${time.toIso8601String()}</time></trkpt>';
}

void main() {
  test('GPX horodaté : nom, temps et distance', () {
    final ghost = parseGpxGhost(
      gpx([for (var s = 0; s <= 300; s++) pt(s, s * 10 / 3)]),
    );
    expect(ghost.name, 'Footing du dimanche');
    expect(ghost.totalTimeS, 300);
    expect(ghost.totalDistanceM, closeTo(1000, 15));
    expect(ghost.hasRoute, isTrue);
  });

  test('point aberrant ignoré', () {
    final points = [for (var s = 0; s <= 120; s++) pt(s, s * 3.0)];
    points[60] = pt(60, 2000);
    final ghost = parseGpxGhost(gpx(points));
    expect(ghost.totalDistanceM, closeTo(360, 10));
  });

  test('sans horodatage ou illisible : erreur claire', () {
    expect(
      () => parseGpxGhost(gpx(['<trkpt lat="45" lon="4"></trkpt>'])),
      throwsA(isA<FormatException>()),
    );
    expect(() => parseGpxGhost('pas du xml'), throwsFormatException);
  });
}
