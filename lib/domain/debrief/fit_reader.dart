import 'dart:typed_data';

import '../gps_tracker.dart';
import 'activity.dart';

/// Lecteur minimal de fichiers FIT (Garmin, Coros, Suunto, Wahoo…) : seuls
/// les messages « record » (n° 20) sont lus, le reste est sauté.
/// Spécification : FIT SDK, « Flexible and Interoperable Data Transfer ».
RawActivity parseFitActivity(Uint8List bytes, {String name = 'Sortie'}) {
  if (bytes.length < 14 ||
      String.fromCharCodes(bytes.sublist(8, 12)) != '.FIT') {
    throw const FormatException('Fichier FIT illisible.');
  }
  final data = ByteData.sublistView(bytes);
  final headerSize = bytes[0];
  final dataSize = data.getUint32(4, Endian.little);
  final end = (headerSize + dataSize).clamp(0, bytes.length);
  final definitions = <int, _Definition>{};
  final samples = <ActivitySample>[];
  var offset = headerSize;
  int? lastTimestamp;

  while (offset < end) {
    final header = bytes[offset++];
    if (header & 0x80 != 0) {
      // En-tête compressé : type local sur 2 bits, décalage de temps 5 bits.
      final local = (header >> 5) & 0x03;
      final def = definitions[local];
      if (def == null) throw const FormatException('Fichier FIT corrompu.');
      final timeOffset = header & 0x1F;
      if (lastTimestamp != null) {
        var t = (lastTimestamp & ~0x1F) + timeOffset;
        if (timeOffset < (lastTimestamp & 0x1F)) t += 0x20;
        lastTimestamp = t;
      }
      final fields = def.read(data, offset);
      offset += def.size;
      if (def.global == _recordMessage) {
        fields[_timestampField] ??= lastTimestamp;
        _addSample(samples, fields);
      }
      continue;
    }
    final local = header & 0x0F;
    if (header & 0x40 != 0) {
      final hasDeveloperFields = header & 0x20 != 0;
      final def = _Definition.parse(data, offset, hasDeveloperFields);
      definitions[local] = def;
      offset += def.definitionLength;
      continue;
    }
    final def = definitions[local];
    if (def == null) throw const FormatException('Fichier FIT corrompu.');
    final fields = def.read(data, offset);
    offset += def.size;
    if (fields[_timestampField] case final t?) lastTimestamp = t;
    if (def.global == _recordMessage) _addSample(samples, fields);
  }
  if (samples.length < 2) {
    throw const FormatException('Ce FIT ne contient pas de sortie.');
  }
  return RawActivity(name: name, samples: samples);
}

const _recordMessage = 20;
const _timestampField = 253;

/// Secondes FIT : depuis le 31 décembre 1989 à minuit UTC.
final _fitEpoch = DateTime.utc(1989, 12, 31);

/// 2³¹ semicercles = 180°.
const _semicircleToDegrees = 180 / 2147483648;

void _addSample(List<ActivitySample> samples, Map<int, int?> f) {
  final t = f[_timestampField];
  if (t == null) return;
  final lat = f[0], lon = f[1];
  final altitude = f[78] ?? f[2];
  samples.add(
    ActivitySample(
      time: _fitEpoch.add(Duration(seconds: t)),
      position: lat == null || lon == null
          ? null
          : GeoPoint(lat * _semicircleToDegrees, lon * _semicircleToDegrees),
      elevationM: altitude == null ? null : altitude / 5 - 500,
      heartRate: f[3],
      cadence: f[4],
      distanceM: f[5] == null ? null : f[5]! / 100,
    ),
  );
}

class _Field {
  const _Field(this.number, this.size, this.baseType);
  final int number;
  final int size;
  final int baseType;
}

class _Definition {
  _Definition(
    this.global,
    this.bigEndian,
    this.fields,
    this.extraSize,
    this.definitionLength,
  );

  factory _Definition.parse(ByteData data, int offset, bool developer) {
    final bigEndian = data.getUint8(offset + 1) == 1;
    final global = data.getUint16(
      offset + 2,
      bigEndian ? Endian.big : Endian.little,
    );
    final count = data.getUint8(offset + 4);
    var p = offset + 5;
    final fields = <_Field>[];
    for (var i = 0; i < count; i++) {
      fields.add(
        _Field(data.getUint8(p), data.getUint8(p + 1), data.getUint8(p + 2)),
      );
      p += 3;
    }
    var extra = 0;
    if (developer) {
      final devCount = data.getUint8(p++);
      for (var i = 0; i < devCount; i++) {
        extra += data.getUint8(p + 1);
        p += 3;
      }
    }
    return _Definition(global, bigEndian, fields, extra, p - offset);
  }

  final int global;
  final bool bigEndian;
  final List<_Field> fields;

  /// Octets des champs « développeur », ignorés.
  final int extraSize;
  final int definitionLength;

  int get size => fields.fold(0, (s, f) => s + f.size) + extraSize;

  /// Valeurs entières des champs ; `null` si la valeur est « invalide ».
  Map<int, int?> read(ByteData data, int offset) {
    final endian = bigEndian ? Endian.big : Endian.little;
    final values = <int, int?>{};
    var p = offset;
    for (final f in fields) {
      values[f.number] = _value(data, p, f, endian);
      p += f.size;
    }
    return values;
  }

  static int? _value(ByteData data, int p, _Field f, Endian endian) {
    final type = f.baseType & 0x1F;
    return switch ((type, f.size)) {
      (0x00 || 0x02 || 0x0A, 1) => _valid(data.getUint8(p), 0xFF, 0x0A, type),
      (0x01, 1) => _valid(data.getInt8(p), 0x7F, null, type),
      (0x04 || 0x0B, 2) => _valid(
        data.getUint16(p, endian),
        0xFFFF,
        0x0B,
        type,
      ),
      (0x03, 2) => _valid(data.getInt16(p, endian), 0x7FFF, null, type),
      (0x06 || 0x0C, 4) => _valid(
        data.getUint32(p, endian),
        0xFFFFFFFF,
        0x0C,
        type,
      ),
      (0x05, 4) => _valid(data.getInt32(p, endian), 0x7FFFFFFF, null, type),
      _ => null,
    };
  }

  /// Les types « z » (0x0A, 0x0B, 0x0C) marquent l'invalide par 0.
  static int? _valid(int v, int invalid, int? zType, int type) =>
      v == invalid || (type == zType && v == 0) ? null : v;
}
