import 'measurement_method.dart';
import 'stage_protocol.dart';

/// Réglages complets d'un test par paliers, tels que l'utilisateur les a saisis.
class StagedTestSetup {
  const StagedTestSetup({
    required this.test,
    required this.protocol,
    required this.maxSpeedKmh,
    required this.method,
  });

  /// Réglages par défaut : le protocole officiel, jusqu'à 20 km/h.
  StagedTestSetup.defaults(this.test)
    : protocol = test.defaultProtocol,
      maxSpeedKmh = 20,
      method = MeasurementMethod.tape;

  final StagedTest test;
  final StageProtocol protocol;

  /// Vitesse du dernier palier de la piste générée.
  final double maxSpeedKmh;
  final MeasurementMethod method;

  List<String> get validationErrors => [
    ...protocol.validationErrors,
    if (protocol.incrementKmh == 0) "L'incrément doit être positif.",
    if (protocol.isValid && !(maxSpeedKmh > protocol.startSpeedKmh))
      'La vitesse maximale doit dépasser la vitesse de départ.',
  ];

  bool get isValid => validationErrors.isEmpty;

  /// Nombre de paliers jusqu'à [maxSpeedKmh] inclus.
  int get stageCount =>
      ((maxSpeedKmh - protocol.startSpeedKmh) / protocol.incrementKmh + 1e-9)
          .floor() +
      1;

  Duration get maxDuration => protocol.stageDuration * stageCount;

  /// Temps entre deux bips au premier palier.
  Duration get firstBeepInterval => Duration(
    microseconds: (protocol.markerSpacingM / protocol.speedMs(1) * 1e6).round(),
  );

  Map<String, Object?> toJson() => {
    'test': test.name,
    'startSpeedKmh': protocol.startSpeedKmh,
    'incrementKmh': protocol.incrementKmh,
    'stageSeconds': protocol.stageDuration.inMilliseconds / 1000,
    'markerSpacingM': protocol.markerSpacingM,
    'maxSpeedKmh': maxSpeedKmh,
    'method': method.name,
  };

  /// Relit des réglages enregistrés ; `null` si le format est inattendu.
  static StagedTestSetup? fromJson(Map<String, Object?> json) {
    try {
      return StagedTestSetup(
        test: StagedTest.values.byName(json['test']! as String),
        protocol: StageProtocol(
          startSpeedKmh: (json['startSpeedKmh']! as num).toDouble(),
          incrementKmh: (json['incrementKmh']! as num).toDouble(),
          stageDuration: Duration(
            milliseconds: ((json['stageSeconds']! as num) * 1000).round(),
          ),
          markerSpacingM: (json['markerSpacingM']! as num).toDouble(),
        ),
        maxSpeedKmh: (json['maxSpeedKmh']! as num).toDouble(),
        method: MeasurementMethod.values.byName(json['method']! as String),
      );
    } on Object {
      return null;
    }
  }
}
