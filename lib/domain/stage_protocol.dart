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

  final double startSpeedKmh;
  final double incrementKmh;
  final Duration stageDuration;
  final double markerSpacingM;

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
