import 'dart:math';

import '../course_profile.dart';
import 'effort_track.dart';
import 'session_type.dart';

/// Un kilomètre de la sortie.
class KmSplit {
  const KmSplit({
    required this.index,
    required this.lengthM,
    required this.timeS,
    required this.gapPaceS,
    required this.elevationDeltaM,
  });

  /// 1 pour le premier km.
  final int index;
  final double lengthM;
  final double timeS;

  /// Allure corrigée de la pente (s/km).
  final double gapPaceS;
  final double elevationDeltaM;

  double get paceS => timeS / lengthM * 1000;
}

/// a) Gestion de l'allure.
class PacingAnalysis {
  PacingAnalysis._({
    required this.splits,
    required this.firstHalfS,
    required this.secondHalfS,
    required this.fastStartPercent,
    required this.irregularity,
    required this.gainableS,
    required this.averageGapPaceS,
  });

  /// Exposant du coût de l'effort selon la vitesse (ADR 0010).
  static const effortExponent = 3.0;

  /// Longueur des tronçons pour le temps gagnable (gomme le bruit GPS).
  static const segmentM = 200.0;

  factory PacingAnalysis.of(EffortTrack track, SessionType type) {
    final d = track.distanceM;
    final splits = <KmSplit>[];
    final profile = track.profile;
    double elevationAt(double m) {
      if (profile == null) return 0;
      final i = (m / CourseProfile.stepM).round().clamp(
        0,
        profile.elevations.length - 1,
      );
      return profile.elevations[i];
    }

    for (var from = 0.0; from < d - 1; from += 1000) {
      final to = min(from + 1000, d);
      // Dernier bout de moins de 200 m : pas un split.
      if (to - from < 200) break;
      splits.add(
        KmSplit(
          index: splits.length + 1,
          lengthM: to - from,
          timeS: track.timeAt(to) - track.timeAt(from),
          gapPaceS: track.gapPaceBetween(from, to),
          elevationDeltaM: elevationAt(to) - elevationAt(from),
        ),
      );
    }

    final half = track.timeAt(d / 2);
    final averageGap = track.gapPaceBetween(0, d);
    double? fastStart;
    if (d >= 6000 && averageGap > 0) {
      final start = track.gapPaceBetween(0, 3000);
      fastStart = (averageGap - start) / averageGap * 100;
    }

    final full = [
      for (final s in splits)
        if (s.lengthM >= 900) s.gapPaceS,
    ];

    return PacingAnalysis._(
      splits: splits,
      firstHalfS: half,
      secondHalfS: track.timeS - half,
      fastStartPercent: fastStart,
      irregularity: full.length < 3 ? null : coefficientOfVariation(full),
      gainableS: type == SessionType.interval ? null : _gainable(track),
      averageGapPaceS: averageGap,
    );
  }

  /// Temps gagnable : même effort total, couru à allure corrigée régulière.
  /// Effort = Σ durée × vitesse^k (k = [effortExponent]) sur des tronçons
  /// de [segmentM] en distance équivalent plat. À effort égal, la vitesse
  /// constante v* vérifie v*^(k−1) = effort / distance ; le temps régulier
  /// est distance / v*, jamais plus long que le temps réel.
  static double _gainable(EffortTrack track) {
    final d = track.distanceM;
    var effort = 0.0;
    var eqTotal = 0.0;
    var timeTotal = 0.0;
    for (var from = 0.0; from < d - 1; from += segmentM) {
      final to = min(from + segmentM, d);
      final eq = track.equivalentAt(to) - track.equivalentAt(from);
      final dt = track.timeAt(to) - track.timeAt(from);
      if (eq <= 0 || dt <= 0) continue;
      final v = eq / dt;
      effort += dt * pow(v, effortExponent);
      eqTotal += eq;
      timeTotal += dt;
    }
    if (eqTotal == 0) return 0;
    final steady = pow(effort / eqTotal, 1 / (effortExponent - 1));
    return max(0, timeTotal - eqTotal / steady);
  }

  final List<KmSplit> splits;
  final double firstHalfS;
  final double secondHalfS;

  /// % plus rapide (allure corrigée) sur les 3 premiers km que la moyenne ;
  /// `null` sous 6 km.
  final double? fastStartPercent;

  /// Coefficient de variation de l'allure corrigée par km ; `null` sous 3 km.
  final double? irregularity;

  /// `null` pour le fractionné (les variations sont voulues).
  final double? gainableS;
  final double averageGapPaceS;

  /// > 0 : seconde moitié plus lente (split positif).
  double get splitDeltaS => secondHalfS - firstHalfS;
}

/// d) Une montée ou une descente, comparée à l'allure équivalent plat.
class HillReport {
  const HillReport({
    required this.section,
    required this.gain,
    required this.loss,
    required this.timeS,
    required this.expectedS,
    required this.peakHeartRate,
    required this.afterSlowdownS,
  });

  final CourseSection section;
  final double gain;
  final double loss;
  final double timeS;

  /// Temps à l'allure équivalent plat moyenne de la sortie.
  final double expectedS;
  final int? peakHeartRate;

  /// Ralentissement (s/km, allure corrigée) sur les 2 km suivants par
  /// rapport à la moyenne ; `null` si la sortie s'arrête avant.
  final double? afterSlowdownS;

  /// > 0 : temps perdu sur la section.
  double get lostS => timeS - expectedS;
}

List<HillReport> hillReports(EffortTrack track) {
  final profile = track.profile;
  if (profile == null) return const [];
  final average = track.gapPaceBetween(0, track.distanceM);
  return [
    for (final s in splitSections(profile))
      if (s.kind != SectionKind.flat)
        () {
          final c = profile.climb(s.from, s.to);
          final eq = track.equivalentAt(s.endM) - track.equivalentAt(s.startM);
          final afterEnd = s.endM + 2000;
          return HillReport(
            section: s,
            gain: c.gain,
            loss: c.loss,
            timeS: track.timeAt(s.endM) - track.timeAt(s.startM),
            expectedS: eq / 1000 * average,
            peakHeartRate: track.peakHeartRate(s.startM, s.endM),
            afterSlowdownS: afterEnd > track.distanceM
                ? null
                : track.gapPaceBetween(s.endM, afterEnd) - average,
          );
        }(),
  ];
}

/// f) Allure moyenne comparée à la VMA.
class VmaComparison {
  const VmaComparison({
    required this.percent,
    required this.expected,
    required this.verdict,
  });

  /// Allure corrigée moyenne en % de VMA.
  final double percent;

  /// Plage attendue pour ce type de séance et cette durée (% de VMA).
  final ({double low, double high}) expected;
  final VmaVerdict verdict;
}

enum VmaVerdict { slow, inRange, fast }

/// Plage habituelle : endurance et sortie longue 60–75 % de VMA ; en
/// course, selon la durée (≈ 95 % sur 10 min, 90 % sur 20 min, 85 % sur
/// 45 min, 80 % sur 1 h 30, 75 % sur 3 h). `null` pour le fractionné.
VmaComparison? compareToVma(
  EffortTrack track,
  SessionType type,
  double vmaKmh,
) {
  if (type == SessionType.interval || track.timeS <= 0) return null;
  final gapKmh = track.equivalentM / track.timeS * 3.6;
  final percent = gapKmh / vmaKmh * 100;
  final ({double low, double high}) expected;
  if (type == SessionType.race) {
    final minutes = track.timeS / 60;
    final center = switch (minutes) {
      <= 10 => 95.0,
      <= 20 => 92.0,
      <= 45 => 87.0,
      <= 90 => 82.0,
      <= 180 => 78.0,
      _ => 72.0,
    };
    expected = (low: center - 3, high: center + 3);
  } else {
    expected = (low: 60.0, high: 75.0);
  }
  return VmaComparison(
    percent: percent,
    expected: expected,
    // Comparé à l'arrondi affiché : « 75 % » est dans « 60–75 % ».
    verdict: percent.round() < expected.low
        ? VmaVerdict.slow
        : percent.round() > expected.high
        ? VmaVerdict.fast
        : VmaVerdict.inRange,
  );
}
