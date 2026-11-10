import '../gps_tracker.dart';
import 'session_type.dart';

/// Un débrief gardé dans l'historique : les résultats, pas la trace.
class DebriefSummary {
  const DebriefSummary({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.distanceM,
    required this.movingS,
    required this.score,
    required this.findings,
    this.gainableS,
    this.gapPaceS,
    this.elevationGainM,
    this.averageHeartRate,
    this.driftPercent,
    this.averageCadence,
    this.vmaPercent,
    this.start,
  });

  final String id;
  final DateTime date;
  final String name;
  final SessionType type;
  final double distanceM;
  final double movingS;
  final int score;

  /// Les constats de l'« En bref ».
  final List<String> findings;
  final double? gainableS;

  /// Allure corrigée de la pente (s/km).
  final double? gapPaceS;
  final double? elevationGainM;
  final double? averageHeartRate;
  final double? driftPercent;
  final double? averageCadence;
  final double? vmaPercent;

  /// Point de départ (pour reconnaître un même parcours).
  final GeoPoint? start;

  double get paceS => distanceM == 0 ? 0 : movingS / distanceM * 1000;

  DebriefSummary copyWith({
    SessionType? type,
    int? score,
    List<String>? findings,
    double? gainableS,
    double? driftPercent,
    double? vmaPercent,
  }) => DebriefSummary(
    id: id,
    date: date,
    name: name,
    type: type ?? this.type,
    distanceM: distanceM,
    movingS: movingS,
    score: score ?? this.score,
    findings: findings ?? this.findings,
    gainableS: gainableS ?? this.gainableS,
    gapPaceS: gapPaceS,
    elevationGainM: elevationGainM,
    averageHeartRate: averageHeartRate,
    driftPercent: driftPercent ?? this.driftPercent,
    averageCadence: averageCadence,
    vmaPercent: vmaPercent ?? this.vmaPercent,
    start: start,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'name': name,
    'type': type.name,
    'distanceM': distanceM,
    'movingS': movingS,
    'score': score,
    'findings': findings,
    'gainableS': ?gainableS,
    'gapPaceS': ?gapPaceS,
    'elevationGainM': ?elevationGainM,
    'averageHeartRate': ?averageHeartRate,
    'driftPercent': ?driftPercent,
    'averageCadence': ?averageCadence,
    'vmaPercent': ?vmaPercent,
    if (start case final s?) 'start': [s.latitude, s.longitude],
  };

  static DebriefSummary? fromJson(Map<String, Object?> json) {
    double? num_(String key) => (json[key] as num?)?.toDouble();
    try {
      final start = json['start'] as List?;
      return DebriefSummary(
        id: json['id']! as String,
        date: DateTime.parse(json['date']! as String),
        name: json['name']! as String,
        type: SessionType.values.byName(json['type']! as String),
        distanceM: num_('distanceM')!,
        movingS: num_('movingS')!,
        score: json['score']! as int,
        findings: [for (final f in json['findings']! as List) f as String],
        gainableS: num_('gainableS'),
        gapPaceS: num_('gapPaceS'),
        elevationGainM: num_('elevationGainM'),
        averageHeartRate: num_('averageHeartRate'),
        driftPercent: num_('driftPercent'),
        averageCadence: num_('averageCadence'),
        vmaPercent: num_('vmaPercent'),
        start: start == null
            ? null
            : GeoPoint(
                (start[0] as num).toDouble(),
                (start[1] as num).toDouble(),
              ),
      );
    } on Object {
      return null;
    }
  }
}

/// Même parcours : départs à moins de 300 m et distances à 5 % près.
bool sameRoute(DebriefSummary a, DebriefSummary b) {
  final sa = a.start, sb = b.start;
  if (sa == null || sb == null) return false;
  final longest = a.distanceM > b.distanceM ? a.distanceM : b.distanceM;
  return haversineM(sa, sb) < 300 &&
      (a.distanceM - b.distanceM).abs() <= longest * 0.05;
}
