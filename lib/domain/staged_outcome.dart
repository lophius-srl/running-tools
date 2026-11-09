import 'beep_schedule.dart';
import 'stage_protocol.dart';
import 'test_results.dart';

/// Où le coureur a décroché dans un test par paliers.
class StagedOutcome {
  const StagedOutcome({
    required this.test,
    required this.protocol,
    required this.completedStages,
    required this.fractionOfNextStage,
    required this.distanceM,
  });

  /// Calcule le résultat à [testTimeS] secondes après le départ.
  factory StagedOutcome.at(
    StagedTest test,
    BeepSchedule schedule,
    double testTimeS,
  ) {
    if (testTimeS <= 0) {
      return StagedOutcome(
        test: test,
        protocol: schedule.protocol,
        completedStages: 0,
        fractionOfNextStage: 0,
        distanceM: 0,
      );
    }
    final position = schedule.positionAt(testTimeS);
    // Fin de la piste : le dernier palier est complet.
    final stageDone = position.fractionOfStage >= 1;
    return StagedOutcome(
      test: test,
      protocol: schedule.protocol,
      completedStages: stageDone ? position.stage : position.stage - 1,
      fractionOfNextStage: stageDone ? 0 : position.fractionOfStage,
      distanceM: position.distanceM,
    );
  }

  final StagedTest test;
  final StageProtocol protocol;
  final int completedStages;

  /// Part courue du palier entamé, dans [0, 1[.
  final double fractionOfNextStage;
  final double distanceM;

  bool get hasResult => completedStages >= 1;

  /// Vitesse retenue ; `null` si aucun palier n'est complet.
  double? reachedSpeedKmh({required bool prorata}) => hasResult
      ? reachedSpeedKmhFor(
          protocol,
          completedStages: completedStages,
          fractionOfNextStage: fractionOfNextStage,
          prorata: prorata,
        )
      : null;

  /// VMA et VO2max ; `null` si aucun palier n'est complet.
  TestResult? result({required bool prorata}) {
    final speed = reachedSpeedKmh(prorata: prorata);
    if (speed == null) return null;
    return switch (test) {
      StagedTest.vameval => vamevalResult(speed),
      StagedTest.lucLeger => lucLegerResult(speed),
    };
  }
}
