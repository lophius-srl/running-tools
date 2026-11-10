import 'dart:math';
import 'dart:typed_data';

/// Sorties de référence pour les tests du débrief : générées avec une graine
/// fixe, donc identiques à chaque exécution.
class FixturePoint {
  const FixturePoint(
    this.second,
    this.northM,
    this.elevation,
    this.hr,
    this.cad,
  );
  final int second;
  final double northM;
  final double elevation;
  final int? hr;

  /// Pas par minute pour un pied (comme Strava / Garmin).
  final int? cad;
}

final _start = DateTime.utc(2026, 11, 8, 9);

double _lat(double northM) => 45.75 + northM / 6371000 * 180 / pi;

/// Footing de [km] km à [kmh] km/h, avec bruit GPS, FC et cadence,
/// et une pause de [pauseS] secondes au km 2 (montre en marche).
List<FixturePoint> easyRun({
  double km = 5,
  double kmh = 11,
  int pauseS = 0,
  bool withHeartRate = true,
  bool withCadence = true,
  int seed = 1,
}) {
  final random = Random(seed);
  final points = <FixturePoint>[];
  var d = 0.0;
  var s = 0;
  var paused = 0;
  while (d < km * 1000) {
    final stopped = pauseS > 0 && d >= 2000 && paused < pauseS;
    if (stopped) {
      paused++;
    } else {
      d += kmh / 3.6;
    }
    points.add(
      FixturePoint(
        s,
        d + (random.nextDouble() - 0.5) * 4,
        200 + (random.nextDouble() - 0.5) * 2,
        withHeartRate ? 140 + (s ~/ 120) + random.nextInt(3) : null,
        withCadence ? (stopped ? 0 : 84 + random.nextInt(3)) : null,
      ),
    );
    s++;
  }
  return points;
}

/// GPX au format de l'export Strava (extensions Garmin).
String toGpx(List<FixturePoint> points, {String name = 'Footing du dimanche'}) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write(
      '<gpx creator="StravaGPX" version="1.1" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">\n',
    )
    ..write('<metadata><time>${_start.toIso8601String()}</time></metadata>\n')
    ..write('<trk><name>$name</name><type>running</type><trkseg>\n');
  for (final p in points) {
    buffer.write(
      '<trkpt lat="${_lat(p.northM)}" lon="4.85">'
      '<ele>${p.elevation.toStringAsFixed(1)}</ele>'
      '<time>${_start.add(Duration(seconds: p.second)).toIso8601String()}</time>',
    );
    if (p.hr != null || p.cad != null) {
      buffer.write('<extensions><gpxtpx:TrackPointExtension>');
      if (p.hr != null) buffer.write('<gpxtpx:hr>${p.hr}</gpxtpx:hr>');
      if (p.cad != null) buffer.write('<gpxtpx:cad>${p.cad}</gpxtpx:cad>');
      buffer.write('</gpxtpx:TrackPointExtension></extensions>');
    }
    buffer.write('</trkpt>\n');
  }
  buffer.write('</trkseg></trk></gpx>\n');
  return buffer.toString();
}

/// Fichier FIT minimal : un message file_id puis des messages record
/// (timestamp, position, altitude, FC, cadence, distance montre).
/// Le dernier point utilise un en-tête à horodatage compressé.
Uint8List toFit(List<FixturePoint> points) {
  final body = BytesBuilder();
  void u8(int v) => body.addByte(v & 0xFF);
  void u16(int v) => body.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void u32(int v) => body.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );
  void s32(int v) => body.add(
    (ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List(),
  );

  // Définition locale 1 : file_id (global 0), un champ type (enum).
  u8(0x41);
  u8(0);
  u8(0);
  u16(0);
  u8(1);
  u8(0);
  u8(1);
  u8(0x00);
  u8(0x01);
  u8(4); // donnée : type = activité
  // Définition locale 0 : record (global 20).
  u8(0x40);
  u8(0);
  u8(0);
  u16(20);
  u8(7);
  for (final (num, size, type) in [
    (253, 4, 0x86),
    (0, 4, 0x85),
    (1, 4, 0x85),
    (78, 4, 0x86),
    (3, 1, 0x02),
    (4, 1, 0x02),
    (5, 4, 0x86),
  ]) {
    u8(num);
    u8(size);
    u8(type);
  }
  final epoch = DateTime.utc(1989, 12, 31);
  int semicircles(double deg) => (deg / 180 * 2147483648).round();
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final t = _start
        .add(Duration(seconds: p.second))
        .difference(epoch)
        .inSeconds;
    final compressed = i == points.length - 1;
    // En-tête compressé : bit 7, type local 0, 5 bits de temps.
    u8(compressed ? 0x80 | (t & 0x1F) : 0x00);
    u32(compressed ? 0xFFFFFFFF : t);
    s32(semicircles(_lat(p.northM)));
    s32(semicircles(4.85));
    u32(((p.elevation + 500) * 5).round());
    u8(p.hr ?? 0xFF);
    u8(p.cad ?? 0xFF);
    u32((p.northM.clamp(0, double.infinity) * 100).round());
  }
  final data = body.toBytes();
  final header = ByteData(14)
    ..setUint8(0, 14)
    ..setUint8(1, 0x20)
    ..setUint16(2, 2132, Endian.little)
    ..setUint32(4, data.length, Endian.little);
  final bytes = BytesBuilder()
    ..add(header.buffer.asUint8List(0, 8))
    ..add('.FIT'.codeUnits)
    ..add([0, 0])
    ..add(data)
    ..add([0, 0]);
  return bytes.toBytes();
}

/// Sortie scénarisée : vitesse [kmhAt] et altitude [elevationAt] selon la
/// distance (m), FC [hrAt] selon la distance et le temps. Bruit GPS ±[noiseM].
List<FixturePoint> scriptedRun({
  required double km,
  required double Function(double d) kmhAt,
  double Function(double d)? elevationAt,
  int? Function(double d, int second)? hrAt,
  int? Function(double d, int second)? cadAt,
  double noiseM = 2,
  int seed = 7,
}) {
  final random = Random(seed);
  final points = <FixturePoint>[];
  var d = 0.0;
  var s = 0;
  while (d < km * 1000) {
    d += kmhAt(d) / 3.6;
    points.add(
      FixturePoint(
        s,
        d + (random.nextDouble() - 0.5) * 2 * noiseM,
        elevationAt?.call(d) ?? 200,
        hrAt?.call(d, s),
        cadAt?.call(d, s),
      ),
    );
    s++;
  }
  return points;
}

/// 2 km plat, 1 km à +6 %, 1 km à −6 %, puis plat (altitude selon la
/// distance en m).
double hillAt(double d) {
  if (d <= 2000) return 200;
  if (d <= 3000) return 200 + (d - 2000) * 0.06;
  if (d <= 4000) return 260 - (d - 3000) * 0.06;
  return 200;
}
