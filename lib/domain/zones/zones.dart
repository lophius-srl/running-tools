import '../training_paces.dart';

/// Les 5 zones d'entraînement.
enum ZoneId {
  z1(
    'Z1',
    'Récupération',
    'Footing de récupération, échauffement, retour au calme.',
  ),
  z2(
    'Z2',
    'Endurance fondamentale',
    'La base : footings, sorties longues. Tu peux parler en courant.',
  ),
  z3(
    'Z3',
    'Endurance active',
    'Allure marathon : soutenu mais tenable longtemps.',
  ),
  z4('Z4', 'Seuil', 'Allure semi / 10 km : dur, phrases courtes.'),
  z5('Z5', 'VMA', 'Fractionné court : très dur, quelques minutes au plus.');

  const ZoneId(this.short, this.label, this.usage);

  final String short;
  final String label;
  final String usage;
}

/// Bornes des zones : la borne haute de chaque zone (la basse de Z1 est
/// ouverte). Ajuster une borne déplace la fin d'une zone et le début de la
/// suivante : jamais de trou ni de chevauchement.
class ZoneSettings {
  const ZoneSettings({
    this.paceUpper = defaultPaceUpper,
    this.heartRateUpper = defaultHeartRateUpper,
    this.heartRateUpperBpm = const {},
  });

  /// % de VMA (borne haute de Z1 à Z5).
  static const defaultPaceUpper = [60.0, 75.0, 85.0, 92.0, 105.0];

  /// % de FC de réserve (borne haute de Z1 à Z5).
  static const defaultHeartRateUpper = [60.0, 72.0, 82.0, 90.0, 100.0];

  final List<double> paceUpper;
  final List<double> heartRateUpper;

  /// Bornes FC fixées directement en bpm (index de zone → bpm), prioritaires
  /// sur le %.
  final Map<int, int> heartRateUpperBpm;

  bool get isDefault =>
      _same(paceUpper, defaultPaceUpper) &&
      _same(heartRateUpper, defaultHeartRateUpper) &&
      heartRateUpperBpm.isEmpty;

  static bool _same(List<double> a, List<double> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  ZoneSettings withPaceUpper(int zone, double percent) => ZoneSettings(
    paceUpper: [...paceUpper]..[zone] = percent,
    heartRateUpper: heartRateUpper,
    heartRateUpperBpm: heartRateUpperBpm,
  );

  ZoneSettings withHeartRateUpper(int zone, double percent) => ZoneSettings(
    paceUpper: paceUpper,
    heartRateUpper: [...heartRateUpper]..[zone] = percent,
    heartRateUpperBpm: {...heartRateUpperBpm}..remove(zone),
  );

  ZoneSettings withHeartRateUpperBpm(int zone, int bpm) => ZoneSettings(
    paceUpper: paceUpper,
    heartRateUpper: heartRateUpper,
    heartRateUpperBpm: {...heartRateUpperBpm, zone: bpm},
  );

  /// Bornes croissantes et dans des plages plausibles.
  bool get isValid {
    bool increasing(List<num> v) =>
        [for (var i = 1; i < v.length; i++) v[i] > v[i - 1]].every((x) => x);
    return paceUpper.length == 5 &&
        heartRateUpper.length == 5 &&
        increasing(paceUpper) &&
        increasing(heartRateUpper) &&
        paceUpper.first > 30 &&
        paceUpper.last <= 130 &&
        heartRateUpper.last <= 100;
  }

  Map<String, Object?> toJson() => {
    'paceUpper': paceUpper,
    'heartRateUpper': heartRateUpper,
    'heartRateUpperBpm': {
      for (final MapEntry(:key, :value) in heartRateUpperBpm.entries)
        '$key': value,
    },
  };

  static ZoneSettings fromJson(Map<String, Object?>? json) {
    if (json == null) return const ZoneSettings();
    try {
      List<double> list(String key) => [
        for (final v in json[key]! as List) (v as num).toDouble(),
      ];
      final settings = ZoneSettings(
        paceUpper: list('paceUpper'),
        heartRateUpper: list('heartRateUpper'),
        heartRateUpperBpm: {
          for (final MapEntry(:key, :value)
              in (json['heartRateUpperBpm']! as Map).entries)
            int.parse(key as String): value as int,
        },
      );
      return settings.isValid ? settings : const ZoneSettings();
    } on Object {
      return const ZoneSettings();
    }
  }
}

/// Une zone calculée. Les bornes basses de Z1 sont ouvertes (`null`).
class Zone {
  const Zone({
    required this.id,
    required this.minKmh,
    required this.maxKmh,
    required this.minBpm,
    required this.maxBpm,
  });

  final ZoneId id;

  /// `null` sans VMA.
  final double? minKmh;
  final double? maxKmh;

  /// `null` sans FC max ou FC de repos.
  final int? minBpm;
  final int? maxBpm;

  /// Allure la plus lente (au km), `null` si ouverte (Z1).
  Duration? get slowestPace => minKmh == null ? null : paceForSpeed(minKmh!);
  Duration? get fastestPace => maxKmh == null ? null : paceForSpeed(maxKmh!);

  bool get hasPace => maxKmh != null;
  bool get hasHeartRate => maxBpm != null;

  Map<String, Object?> toJson() => {
    'id': id.name,
    'minKmh': minKmh,
    'maxKmh': maxKmh,
    'minBpm': minBpm,
    'maxBpm': maxBpm,
  };

  static Zone fromJson(Map<String, Object?> json) => Zone(
    id: ZoneId.values.byName(json['id']! as String),
    minKmh: (json['minKmh'] as num?)?.toDouble(),
    maxKmh: (json['maxKmh'] as num?)?.toDouble(),
    minBpm: json['minBpm'] as int?,
    maxBpm: json['maxBpm'] as int?,
  );
}

/// Les 5 zones calculées.
class ZoneSet {
  const ZoneSet(this.zones);

  final List<Zone> zones;

  Zone operator [](ZoneId id) => zones[id.index];

  bool get hasPace => zones.first.hasPace;
  bool get hasHeartRate => zones.first.hasHeartRate;

  /// Zone d'une vitesse (km/h), `null` sans VMA. Au-delà de Z5 : Z5.
  ZoneId? zoneForSpeed(double kmh) {
    if (!hasPace) return null;
    for (final z in zones) {
      if (kmh < z.maxKmh!) return z.id;
    }
    return ZoneId.z5;
  }

  /// Zone d'une FC, `null` sans FC.
  ZoneId? zoneForHeartRate(int bpm) {
    if (!hasHeartRate) return null;
    for (final z in zones) {
      if (bpm < z.maxBpm!) return z.id;
    }
    return ZoneId.z5;
  }

  Map<String, Object?> toJson() => {
    'zones': [for (final z in zones) z.toJson()],
  };

  static ZoneSet? fromJson(Map<String, Object?> json) {
    try {
      final zones = [
        for (final z in json['zones']! as List)
          Zone.fromJson(z as Map<String, Object?>),
      ];
      return zones.length == 5 ? ZoneSet(zones) : null;
    } on Object {
      return null;
    }
  }

  /// Mêmes valeurs (allures au 1/100 km/h, FC au bpm).
  bool sameAs(ZoneSet other) {
    double? r(double? v) => v == null ? null : (v * 100).roundToDouble();
    for (var i = 0; i < 5; i++) {
      final a = zones[i], b = other.zones[i];
      if (r(a.minKmh) != r(b.minKmh) ||
          r(a.maxKmh) != r(b.maxKmh) ||
          a.minBpm != b.minBpm ||
          a.maxBpm != b.maxBpm) {
        return false;
      }
    }
    return true;
  }
}

/// Seule source de vérité des zones : aucun écran ne les recalcule.
abstract final class ZoneService {
  /// Allures : vitesse = % × VMA. FC : Karvonen,
  /// FC cible = FC repos + % × (FC max − FC repos), arrondie au bpm.
  static ZoneSet compute({
    double? vmaKmh,
    int? maxHeartRate,
    int? restHeartRate,
    ZoneSettings settings = const ZoneSettings(),
  }) {
    final hr =
        maxHeartRate != null &&
        restHeartRate != null &&
        maxHeartRate > restHeartRate;
    int? bpmAt(int zone) {
      if (!hr) return null;
      if (settings.heartRateUpperBpm[zone] case final bpm?) return bpm;
      return (restHeartRate +
              settings.heartRateUpper[zone] /
                  100 *
                  (maxHeartRate - restHeartRate))
          .round();
    }

    return ZoneSet([
      for (final id in ZoneId.values)
        Zone(
          id: id,
          minKmh: vmaKmh == null || id.index == 0
              ? null
              : vmaKmh * settings.paceUpper[id.index - 1] / 100,
          maxKmh: vmaKmh == null
              ? null
              : vmaKmh * settings.paceUpper[id.index] / 100,
          minBpm: id.index == 0 ? null : bpmAt(id.index - 1),
          maxBpm: bpmAt(id.index),
        ),
    ]);
  }
}

/// Une différence entre deux versions de zones.
class ZoneChange {
  const ZoneChange(this.zone, this.text);
  final ZoneId zone;
  final String text;
}

/// « Z2 : 8'24–6'43 → 8'10–6'32/km · 154–169 → 150–166 bpm ».
List<ZoneChange> diffZones(ZoneSet before, ZoneSet after) => [
  for (final id in ZoneId.values)
    if (paceRange(before[id]) != paceRange(after[id]) ||
        bpmRange(before[id]) != bpmRange(after[id]))
      ZoneChange(id, () {
        final a = before[id], b = after[id];
        final parts = <String>[
          if (paceRange(a) != paceRange(b))
            '${paceRange(a) ?? '–'} → ${paceRange(b) ?? '–'}/km',
          if (bpmRange(a) != bpmRange(b))
            '${bpmRange(a) ?? '–'} → ${bpmRange(b) ?? '–'} bpm',
        ];
        return '${id.short} : ${parts.join(' · ')}';
      }()),
];

/// « 8'24–6'43 », « > 8'24 » pour Z1 ; `null` sans VMA.
String? paceRange(Zone z) {
  final fast = z.fastestPace;
  if (fast == null) return null;
  final slow = z.slowestPace;
  return slow == null
      ? '> ${formatZonePace(fast)}'
      : '${formatZonePace(slow)}–${formatZonePace(fast)}';
}

/// « 154–169 », « < 154 » pour Z1 ; `null` sans FC.
String? bpmRange(Zone z) {
  final max = z.maxBpm;
  if (max == null) return null;
  return z.minBpm == null ? '< $max' : '${z.minBpm}–$max';
}

/// « 8'24 » (minutes ' secondes, comme sur une montre).
String formatZonePace(Duration pace) {
  final s = pace.inSeconds;
  return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}";
}
