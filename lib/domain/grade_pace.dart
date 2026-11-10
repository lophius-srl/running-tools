import 'dart:math';

import 'course_profile.dart';

/// Coût énergétique de la course (J/kg/m) selon la pente [grade]
/// (fraction), Minetti et al. 2002, valable de −45 % à +45 %.
double minettiCost(double grade) {
  final i = grade.clamp(-0.45, 0.45);
  return 155.4 * pow(i, 5) -
      30.4 * pow(i, 4) -
      43.3 * pow(i, 3) +
      46.3 * pow(i, 2) +
      19.5 * i +
      3.6;
}

/// Facteur d'allure à [grade] par rapport au plat (1,05 = 5 % plus lent).
/// Montée : rapport des coûts de Minetti. Descente : seulement un tiers du
/// gain théorique, et plus de gain au-delà de −10 % (on freine). Voir
/// l'ADR 0009.
double gradePaceFactor(double grade) {
  if (grade >= 0) return minettiCost(grade) / minettiCost(0);
  final g = max(grade, -0.10);
  return 1 + (minettiCost(g) / minettiCost(0) - 1) / 3;
}

/// Une section avec son allure et son temps de passage.
class PacedSection {
  const PacedSection({
    required this.section,
    required this.gain,
    required this.loss,
    required this.pace,
    required this.splitS,
  });

  final CourseSection section;
  final double gain;
  final double loss;

  /// Allure cible (temps par km).
  final Duration pace;

  /// Temps de passage cumulé à la fin de la section (s).
  final double splitS;
}

/// Plan d'allures d'un parcours.
class CoursePlan {
  CoursePlan._(this.profile, this.flatPaceSPerM, this.sections);

  /// Depuis une allure de base sur le plat.
  factory CoursePlan.fromFlatPace(
    CourseProfile profile,
    List<CourseSection> sections,
    Duration flatPacePerKm,
  ) => CoursePlan._(
    profile,
    flatPacePerKm.inMilliseconds / 1000 / 1000,
    sections,
  );

  /// Depuis un objectif de temps total : allure de base déduite.
  factory CoursePlan.fromTarget(
    CourseProfile profile,
    List<CourseSection> sections,
    Duration target,
  ) {
    final effort = _effort(profile, 0, profile.elevations.length - 1);
    return CoursePlan._(
      profile,
      target.inMilliseconds / 1000 / effort,
      sections,
    );
  }

  final CourseProfile profile;

  /// Allure sur le plat (s/m).
  final double flatPaceSPerM;
  final List<CourseSection> sections;

  /// Distance « équivalent plat » entre deux indices du profil.
  static double _effort(CourseProfile p, int from, int to) {
    var sum = 0.0;
    for (var i = from; i < to; i++) {
      sum += CourseProfile.stepM * gradePaceFactor(p.gradeAt(i));
    }
    return sum;
  }

  Duration get flatPace =>
      Duration(milliseconds: (flatPaceSPerM * 1000 * 1000).round());

  /// Temps (s) pour atteindre l'indice [to] du profil.
  double timeAt(int to) => flatPaceSPerM * _effort(profile, 0, to);

  double get totalS => timeAt(profile.elevations.length - 1);

  List<PacedSection> get paced => [
    for (final s in sections)
      () {
        final c = profile.climb(s.from, s.to);
        final t = flatPaceSPerM * _effort(profile, s.from, s.to);
        return PacedSection(
          section: s,
          gain: c.gain,
          loss: c.loss,
          pace: Duration(milliseconds: (t / s.lengthM * 1000 * 1000).round()),
          splitS: timeAt(s.to),
        );
      }(),
  ];

  /// Bande d'allure : temps de passage à chaque km (et à l'arrivée).
  List<(double km, double splitS)> get paceBand {
    final steps = (1000 / CourseProfile.stepM).round();
    final last = profile.elevations.length - 1;
    return [
      for (var i = steps; i < last; i += steps)
        (i * CourseProfile.stepM / 1000, timeAt(i)),
      (profile.distanceM / 1000, totalS),
    ];
  }
}
