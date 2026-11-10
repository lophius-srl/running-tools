import 'dart:math';

import 'package:xml/xml.dart';

import 'gps_tracker.dart';

/// Profil d'un parcours : altitude (m) tous les [stepM] mètres, lissée.
class CourseProfile {
  CourseProfile({required this.name, required List<double> elevations})
    : elevations = List.unmodifiable(elevations) {
    if (elevations.length < 2) {
      throw ArgumentError('Profil trop court.');
    }
  }

  static const stepM = 10.0;

  final String name;
  final List<double> elevations;

  double get distanceM => (elevations.length - 1) * stepM;

  /// Dénivelé positif et négatif (m). Les variations de moins de
  /// [thresholdM] sont ignorées (bruit d'altitude), comme sur les montres.
  ({double gain, double loss}) climb([
    int from = 0,
    int? to,
    double thresholdM = 2,
  ]) {
    var gain = 0.0, loss = 0.0;
    var reference = elevations[from];
    for (var i = from + 1; i <= (to ?? elevations.length - 1); i++) {
      final d = elevations[i] - reference;
      if (d > thresholdM) {
        gain += d;
        reference = elevations[i];
      } else if (d < -thresholdM) {
        loss -= d;
        reference = elevations[i];
      }
    }
    return (gain: gain, loss: loss);
  }

  /// Pente (fraction) du pas [i] → [i + 1].
  double gradeAt(int i) => (elevations[i + 1] - elevations[i]) / stepM;
}

/// Lit un GPX (trace ou itinéraire) avec altitudes. Le temps n'est pas
/// nécessaire. Le profil est rééchantillonné tous les 10 m puis lissé sur
/// [smoothingM] pour gommer le bruit des altitudes GPS.
CourseProfile parseGpxCourse(
  String gpx, {
  String? fallbackName,
  double smoothingM = 100,
}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(gpx);
  } on XmlException {
    throw const FormatException('Fichier GPX illisible.');
  }
  final name = doc
      .findAllElements('name')
      .map((e) => e.innerText.trim())
      .firstWhere(
        (n) => n.isNotEmpty,
        orElse: () => fallbackName ?? 'Parcours',
      );
  final raw = <(GeoPoint, double)>[];
  for (final pt in [
    ...doc.findAllElements('trkpt'),
    ...doc.findAllElements('rtept'),
  ]) {
    final lat = double.tryParse(pt.getAttribute('lat') ?? '');
    final lon = double.tryParse(pt.getAttribute('lon') ?? '');
    final ele = double.tryParse(
      pt.findElements('ele').firstOrNull?.innerText.trim() ?? '',
    );
    if (lat == null || lon == null || ele == null) continue;
    raw.add((GeoPoint(lat, lon), ele));
  }
  if (raw.length < 2) {
    throw const FormatException(
      'Ce GPX ne contient pas de parcours avec altitudes.',
    );
  }
  // Distance cumulée de chaque point.
  final distances = <double>[0];
  for (var i = 1; i < raw.length; i++) {
    distances.add(distances.last + haversineM(raw[i - 1].$1, raw[i].$1));
  }
  if (distances.last < 2 * CourseProfile.stepM) {
    throw const FormatException('Parcours trop court.');
  }
  final resampled = <double>[];
  var j = 0;
  for (var d = 0.0; d <= distances.last; d += CourseProfile.stepM) {
    while (j < distances.length - 2 && distances[j + 1] < d) {
      j++;
    }
    final span = distances[j + 1] - distances[j];
    final f = span == 0 ? 0.0 : ((d - distances[j]) / span).clamp(0.0, 1.0);
    resampled.add(raw[j].$2 + f * (raw[j + 1].$2 - raw[j].$2));
  }
  return CourseProfile(
    name: name,
    elevations: smooth(resampled, (smoothingM / CourseProfile.stepM).round()),
  );
}

/// Moyenne glissante centrée sur [window] points.
List<double> smooth(List<double> values, int window) {
  final half = window ~/ 2;
  if (half == 0) return values;
  return [
    for (var i = 0; i < values.length; i++)
      () {
        final from = max(0, i - half), to = min(values.length - 1, i + half);
        var sum = 0.0;
        for (var k = from; k <= to; k++) {
          sum += values[k];
        }
        return sum / (to - from + 1);
      }(),
  ];
}

enum SectionKind {
  climb('Montée'),
  descent('Descente'),
  flat('Plat');

  const SectionKind(this.label);
  final String label;
}

/// Une portion homogène du parcours.
class CourseSection {
  const CourseSection({
    required this.kind,
    required this.from,
    required this.to,
  });

  final SectionKind kind;

  /// Indices dans le profil (pas de 10 m).
  final int from;
  final int to;

  double get startM => from * CourseProfile.stepM;
  double get endM => to * CourseProfile.stepM;
  double get lengthM => endM - startM;
}

/// Découpe en montées, descentes et plats : pente moyenne sur 100 m, seuil
/// de ±[thresholdGrade] ; les portions de moins de [minLengthM] rejoignent
/// leur voisine.
List<CourseSection> splitSections(
  CourseProfile profile, {
  double thresholdGrade = 0.02,
  double minLengthM = 300,
}) {
  final n = profile.elevations.length - 1;
  const window = 10; // 100 m
  SectionKind kindAt(int i) {
    final from = max(0, i - window ~/ 2);
    final to = min(n, from + window);
    final grade =
        (profile.elevations[to] - profile.elevations[from]) /
        ((to - from) * CourseProfile.stepM);
    if (grade > thresholdGrade) return SectionKind.climb;
    if (grade < -thresholdGrade) return SectionKind.descent;
    return SectionKind.flat;
  }

  var sections = <CourseSection>[];
  for (var i = 0; i < n; i++) {
    final kind = kindAt(i);
    if (sections.isNotEmpty && sections.last.kind == kind) {
      final last = sections.removeLast();
      sections.add(CourseSection(kind: kind, from: last.from, to: i + 1));
    } else {
      sections.add(CourseSection(kind: kind, from: i, to: i + 1));
    }
  }
  // Absorbe les portions trop courtes, la plus courte d'abord.
  while (sections.length > 1) {
    var shortest = 0;
    for (var i = 1; i < sections.length; i++) {
      if (sections[i].lengthM < sections[shortest].lengthM) shortest = i;
    }
    if (sections[shortest].lengthM >= minLengthM) break;
    final s = sections[shortest];
    final prev = shortest > 0 ? sections[shortest - 1] : null;
    final next = shortest < sections.length - 1 ? sections[shortest + 1] : null;
    final into =
        (prev != null && (next == null || prev.lengthM >= next.lengthM))
        ? shortest - 1
        : shortest + 1;
    final target = sections[into];
    sections[into] = CourseSection(
      kind: target.kind,
      from: min(target.from, s.from),
      to: max(target.to, s.to),
    );
    sections.removeAt(shortest);
    sections = _mergeSameKind(sections);
  }
  return sections;
}

List<CourseSection> _mergeSameKind(List<CourseSection> sections) {
  final merged = <CourseSection>[];
  for (final s in sections) {
    if (merged.isNotEmpty && merged.last.kind == s.kind) {
      final last = merged.removeLast();
      merged.add(CourseSection(kind: s.kind, from: last.from, to: s.to));
    } else {
      merged.add(s);
    }
  }
  return merged;
}
