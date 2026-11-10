import 'package:xml/xml.dart';

import 'ghost.dart';
import 'gps_tracker.dart';

/// Lecture d'un GPX en fantôme. La distance passe par le même filtre que la
/// course en direct, pour comparer à armes égales.
Ghost parseGpxGhost(String gpx, {String? fallbackName}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(gpx);
  } on XmlException {
    throw const FormatException('Fichier GPX illisible.');
  }
  final name = doc
      .findAllElements('name')
      .map((e) => e.innerText.trim())
      .firstWhere((n) => n.isNotEmpty, orElse: () => fallbackName ?? 'GPX');
  final tracker = GpsTracker();
  final points = <GhostPoint>[];
  DateTime? start;
  for (final pt in doc.findAllElements('trkpt')) {
    final lat = double.tryParse(pt.getAttribute('lat') ?? '');
    final lon = double.tryParse(pt.getAttribute('lon') ?? '');
    final time = DateTime.tryParse(
      pt.findElements('time').firstOrNull?.innerText ?? '',
    );
    if (lat == null || lon == null || time == null) continue;
    final position = GeoPoint(lat, lon);
    final rejected = tracker.add(
      GpsFix(time: time, position: position, accuracyM: 5),
    );
    if (rejected != null) continue;
    start ??= time;
    final t = time.difference(start).inMilliseconds / 1000;
    points.add(
      GhostPoint(timeS: t, distanceM: tracker.distanceM, position: position),
    );
  }
  if (points.length < 2) {
    throw const FormatException('Ce GPX ne contient pas de trace horodatée.');
  }
  return Ghost(name: name, points: points);
}
