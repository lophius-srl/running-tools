import 'measurement_method.dart';
import 'stage_protocol.dart';
import 'timed_test.dart';

/// Les 4 tests proposés par l'app.
enum TestKind {
  cooper('Cooper'),
  halfCooper('Demi-Cooper'),
  vameval('VAMEVAL'),
  lucLeger('Luc Léger');

  const TestKind(this.label);

  final String label;

  static TestKind ofStaged(StagedTest test) => switch (test) {
    StagedTest.vameval => vameval,
    StagedTest.lucLeger => lucLeger,
  };

  static TestKind ofTimed(TimedTest test) => switch (test) {
    TimedTest.cooper => cooper,
    TimedTest.halfCooper => halfCooper,
  };
}

/// Un test enregistré dans l'historique, avec le setup utilisé.
class TestRecord {
  const TestRecord({
    required this.id,
    required this.date,
    required this.kind,
    required this.vmaKmh,
    required this.vo2max,
    this.distanceM,
    this.completedStages,
    this.fractionOfNextStage,
    this.prorata = false,
    this.protocol,
    this.method,
    this.shoes,
  });

  final String id;
  final DateTime date;
  final TestKind kind;
  final double vmaKmh;
  final double vo2max;

  /// Distance courue (saisie pour Cooper, calculée pour les paliers).
  final double? distanceM;

  /// Tests par paliers : dernier palier complet et part du suivant.
  final int? completedStages;
  final double? fractionOfNextStage;
  final bool prorata;

  /// Tests par paliers : réglages et méthode de mesure des repères.
  final StageProtocol? protocol;
  final MeasurementMethod? method;

  /// Chaussures portées (texte libre).
  final String? shoes;

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'kind': kind.name,
    'vmaKmh': vmaKmh,
    'vo2max': vo2max,
    'distanceM': ?distanceM,
    'completedStages': ?completedStages,
    'fractionOfNextStage': ?fractionOfNextStage,
    'prorata': prorata,
    if (protocol case final p?)
      'protocol': {
        'startSpeedKmh': p.startSpeedKmh,
        'incrementKmh': p.incrementKmh,
        'stageSeconds': p.stageDuration.inMilliseconds / 1000,
        'markerSpacingM': p.markerSpacingM,
      },
    'method': ?method?.name,
    'shoes': ?shoes,
  };

  /// `null` si l'enregistrement est illisible (il est alors ignoré).
  static TestRecord? fromJson(Map<String, Object?> json) {
    try {
      final p = json['protocol'] as Map<String, Object?>?;
      final method = json['method'] as String?;
      return TestRecord(
        id: json['id']! as String,
        date: DateTime.parse(json['date']! as String).toLocal(),
        kind: TestKind.values.byName(json['kind']! as String),
        vmaKmh: (json['vmaKmh']! as num).toDouble(),
        vo2max: (json['vo2max']! as num).toDouble(),
        distanceM: (json['distanceM'] as num?)?.toDouble(),
        completedStages: json['completedStages'] as int?,
        fractionOfNextStage: (json['fractionOfNextStage'] as num?)?.toDouble(),
        prorata: json['prorata'] as bool? ?? false,
        protocol: p == null
            ? null
            : StageProtocol(
                startSpeedKmh: (p['startSpeedKmh']! as num).toDouble(),
                incrementKmh: (p['incrementKmh']! as num).toDouble(),
                stageDuration: Duration(
                  milliseconds: ((p['stageSeconds']! as num) * 1000).round(),
                ),
                markerSpacingM: (p['markerSpacingM']! as num).toDouble(),
              ),
        method: method == null ? null : MeasurementMethod.values.byName(method),
        shoes: json['shoes'] as String?,
      );
    } on Object {
      return null;
    }
  }
}
