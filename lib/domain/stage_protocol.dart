/// Paramètres d'un test par paliers (VAMEVAL, navette…).
class StageProtocol {
  const StageProtocol({
    required this.startSpeedKmh,
    required this.incrementKmh,
    required this.stageDuration,
    required this.markerSpacingM,
  });

  /// VAMEVAL classique : 8 km/h, +0,5 km/h par minute.
  const StageProtocol.vameval({double markerSpacingM = 20})
    : this(
        startSpeedKmh: 8,
        incrementKmh: 0.5,
        stageDuration: const Duration(minutes: 1),
        markerSpacingM: markerSpacingM,
      );

  /// Navette Luc Léger : 8,5 km/h, +0,5 km/h par minute, lignes à 20 m
  /// (un bip à chaque ligne = un demi-tour).
  const StageProtocol.lucLeger({double markerSpacingM = 20})
    : this(
        startSpeedKmh: 8.5,
        incrementKmh: 0.5,
        stageDuration: const Duration(minutes: 1),
        markerSpacingM: markerSpacingM,
      );

  final double startSpeedKmh;
  final double incrementKmh;
  final Duration stageDuration;
  final double markerSpacingM;

  StageProtocol copyWith({
    double? startSpeedKmh,
    double? incrementKmh,
    Duration? stageDuration,
    double? markerSpacingM,
  }) => StageProtocol(
    startSpeedKmh: startSpeedKmh ?? this.startSpeedKmh,
    incrementKmh: incrementKmh ?? this.incrementKmh,
    stageDuration: stageDuration ?? this.stageDuration,
    markerSpacingM: markerSpacingM ?? this.markerSpacingM,
  );

  /// Problèmes de paramétrage, vide si le protocole est utilisable.
  List<String> get validationErrors => [
    if (!(startSpeedKmh > 0)) 'La vitesse de départ doit être positive.',
    if (!(incrementKmh >= 0)) "L'incrément ne peut pas être négatif.",
    if (stageDuration <= Duration.zero)
      'La durée de palier doit être positive.',
    if (!(markerSpacingM > 0)) "L'espacement des repères doit être positif.",
  ];

  bool get isValid => validationErrors.isEmpty;

  double get stageSeconds => stageDuration.inMicroseconds / 1e6;

  /// Vitesse du palier [stage] (numéroté à partir de 1).
  double speedKmh(int stage) => startSpeedKmh + (stage - 1) * incrementKmh;

  double speedMs(int stage) => speedKmh(stage) / 3.6;

  /// Distance cumulée au début du palier [stage] (forme exacte, sans cumul
  /// d'erreurs d'arrondi).
  double distanceAtStageStart(int stage) {
    final completed = stage - 1;
    final speedSumKmh =
        completed * startSpeedKmh +
        incrementKmh * completed * (completed - 1) / 2;
    return speedSumKmh / 3.6 * stageSeconds;
  }
}

/// Tests par paliers proposés, avec leur protocole par défaut.
enum StagedTest {
  vameval('VAMEVAL', StageProtocol.vameval()),
  lucLeger('Navette Luc Léger', StageProtocol.lucLeger());

  const StagedTest(this.label, this.defaultProtocol);

  final String label;
  final StageProtocol defaultProtocol;
}
