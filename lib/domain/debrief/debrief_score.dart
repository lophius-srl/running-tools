import 'dart:math';

import '../course_profile.dart';
import 'cardio_analysis.dart';
import 'pacing_analysis.dart';
import 'session_type.dart';

/// Note de gestion de course sur 100 : on part de 100 et chaque défaut
/// retire des points, plafonnés pour qu'aucun ne domine :
/// - départ trop rapide : 1 point par % au-delà de 3 % (max 15) ;
/// - split positif : 2 points par % de la 1re moitié au-delà de 2 % (max 15) ;
/// - allure mal répartie : 15 points par % du temps gagnable (max 20) ;
/// - côte trop forcée et payée ensuite : 1 point par 4 s/km (max 10 chacune) ;
/// - intensité hors du but (endurance, sortie longue) : 1 point par % du
///   temps au-delà de 20 % (max 20) ;
/// - dérive cardiaque : 1,5 point par % au-delà de 5 % (max 10) ;
/// - chute de cadence : 1 point par % au-delà de 3 % (max 5).
/// En fractionné, seules l'intensité et la cadence comptent.
class DebriefScore {
  const DebriefScore(this.value, this.penalties);

  final int value;

  /// Points retirés, par défaut (pour le détail).
  final Map<String, double> penalties;

  String get label => switch (value) {
    >= 85 => 'Très bien gérée',
    >= 70 => 'Bien gérée',
    >= 50 => 'À améliorer',
    _ => 'Mal gérée',
  };
}

DebriefScore debriefScore({
  required PacingAnalysis pacing,
  required List<HillReport> hills,
  required SessionType type,
  required double movingS,
  ({double share, bool byHeartRate})? zones,
  CardiacDrift? drift,
  CadenceReport? cadence,
}) {
  final penalties = <String, double>{};
  void add(String key, double points, double cap) {
    if (points > 0) penalties[key] = min(points, cap);
  }

  if (type != SessionType.interval) {
    add('Départ rapide', (pacing.fastStartPercent ?? 0) - 3, 15);
    if (pacing.firstHalfS > 0) {
      add(
        'Ralentissement',
        (pacing.splitDeltaS / pacing.firstHalfS * 100 - 2) * 2,
        15,
      );
    }
    if (movingS > 0) {
      add(
        'Allure mal répartie',
        (pacing.gainableS ?? 0) / movingS * 100 * 15,
        20,
      );
    }
    var climbs = 0.0;
    for (final h in hills) {
      final after = h.afterSlowdownS ?? 0;
      if (h.section.kind == SectionKind.climb && h.lostS < -15 && after > 10) {
        climbs += min(10, after / 4);
      }
    }
    add('Côtes trop forcées', climbs, 20);
    add('Dérive cardiaque', ((drift?.percent ?? 0) - 5) * 1.5, 10);
  }
  if (zones != null) add('Trop intense', (zones.share - 0.2) * 100, 20);
  add('Fatigue (cadence)', (cadence?.dropPercent ?? 0) - 3, 5);

  final lost = penalties.values.fold(0.0, (s, p) => s + p);
  return DebriefScore(max(0, 100 - lost).round(), penalties);
}
