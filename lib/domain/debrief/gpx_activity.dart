import 'package:xml/xml.dart';

import '../gps_tracker.dart';
import 'activity.dart';

/// Lit une sortie GPX horodatée, avec FC et cadence si présentes
/// (extensions Garmin `gpxtpx:hr`, `gpxtpx:cad`, reprises par Strava,
/// Suunto, Coros…).
RawActivity parseGpxActivity(String gpx, {String? fallbackName}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(gpx);
  } on XmlException {
    throw const FormatException('Fichier GPX illisible.');
  }
  final name = doc
      .findAllElements('name')
      .map((e) => e.innerText.trim())
      .firstWhere((n) => n.isNotEmpty, orElse: () => fallbackName ?? 'Sortie');
  int? intIn(XmlElement pt, String localName) {
    for (final e in pt.descendants.whereType<XmlElement>()) {
      if (e.name.local == localName) return int.tryParse(e.innerText.trim());
    }
    return null;
  }

  final samples = <ActivitySample>[];
  for (final pt in doc.findAllElements('trkpt')) {
    final time = DateTime.tryParse(
      pt.findElements('time').firstOrNull?.innerText.trim() ?? '',
    );
    if (time == null) continue;
    final lat = double.tryParse(pt.getAttribute('lat') ?? '');
    final lon = double.tryParse(pt.getAttribute('lon') ?? '');
    samples.add(
      ActivitySample(
        time: time,
        position: lat == null || lon == null ? null : GeoPoint(lat, lon),
        elevationM: double.tryParse(
          pt.findElements('ele').firstOrNull?.innerText.trim() ?? '',
        ),
        heartRate: intIn(pt, 'hr'),
        cadence: intIn(pt, 'cad'),
      ),
    );
  }
  if (samples.length < 2) {
    throw const FormatException('Ce GPX ne contient pas de sortie horodatée.');
  }
  return RawActivity(name: name, samples: samples);
}
