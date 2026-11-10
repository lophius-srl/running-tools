import 'dart:math';

import 'clean_activity.dart';
import 'effort_track.dart';
import 'session_type.dart';

/// Ce qui rend une FC douteuse.
enum HeartRateIssue {
  /// Sauts de plus de 25 bpm en quelques secondes.
  spikes,

  /// FC figée plus d'une minute en courant (capteur décroché).
  dropout,

  /// FC « collée » à la cadence : défaut typique du capteur optique.
  cadenceLock,
}

/// Fiabilité de la fréquence cardiaque enregistrée.
class HeartRateQuality {
  const HeartRateQuality(this.issues);

  final Set<HeartRateIssue> issues;

  bool get reliable => issues.isEmpty;
}

HeartRateQuality assessHeartRate(CleanActivity activity) {
  final points = [
    for (final p in activity.points)
      if (p.heartRate != null) p,
  ];
  final issues = <HeartRateIssue>{};
  if (points.length < 10) return HeartRateQuality(issues);

  var spikes = 0;
  var flatS = 0.0, longestFlatS = 0.0;
  var locked = 0, bothPresent = 0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    final dt = b.timeS - a.timeS;
    final dHr = (b.heartRate! - a.heartRate!).abs();
    if (dt <= 3 && dHr > 25) spikes++;
    if (dHr == 0 && dt <= 5) {
      flatS += dt;
      longestFlatS = max(longestFlatS, flatS);
    } else {
      flatS = 0;
    }
    if (b.cadence case final cad? when cad >= 140) {
      bothPresent++;
      if ((b.heartRate! - cad).abs() <= 2) locked++;
    }
  }
  final hours = max(activity.movingS / 3600, 0.25);
  if (spikes / hours >= 6) issues.add(HeartRateIssue.spikes);
  if (longestFlatS >= 60) issues.add(HeartRateIssue.dropout);
  if (bothPresent > 60 && locked / bothPresent >= 0.2) {
    issues.add(HeartRateIssue.cadenceLock);
  }
  return HeartRateQuality(issues);
}

/// FC max observée, moyennée sur 10 s pour ignorer un pic isolé.
int? observedMaxHeartRate(CleanActivity activity) {
  final points = activity.points;
  int? best;
  var lo = 0;
  var sum = 0, count = 0;
  for (var hi = 0; hi < points.length; hi++) {
    if (points[hi].heartRate case final hr?) {
      sum += hr;
      count++;
    }
    while (points[hi].timeS - points[lo].timeS > 10) {
      if (points[lo].heartRate case final hr?) {
        sum -= hr;
        count--;
      }
      lo++;
    }
    if (count >= 5) {
      final mean = (sum / count).round();
      if (best == null || mean > best) best = mean;
    }
  }
  return best;
}

/// b) Dérive cardiaque : efficacité (vitesse équivalent plat / FC) de la
/// 2e moitié comparée à la 1re, échauffement retiré.
class CardiacDrift {
  const CardiacDrift({
    required this.percent,
    required this.firstHalfHeartRate,
    required this.secondHalfHeartRate,
    required this.fromS,
  });

  /// > 0 : il faut plus de battements pour la même vitesse en fin de sortie.
  final double percent;
  final double firstHalfHeartRate;
  final double secondHalfHeartRate;

  /// Début de l'analyse (fin de l'échauffement), en temps de mouvement.
  final double fromS;

  /// Au-delà de 5 % : fatigue, chaleur ou hydratation possibles.
  bool get significant => percent > 5;
}

/// `null` pour le fractionné, sans FC, ou si la sortie dure moins de
/// 30 min après échauffement.
CardiacDrift? cardiacDrift(
  EffortTrack track,
  SessionType type, {
  double warmupS = 600,
}) {
  final a = track.activity;
  if (type == SessionType.interval || !a.hasHeartRate) return null;
  final end = track.timeS;
  if (end - warmupS < 1800) return null;
  final mid = warmupS + (end - warmupS) / 2;

  double? meanHr(double from, double to) {
    var sum = 0.0, weight = 0.0;
    final points = a.points;
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      final hr = p.heartRate;
      if (hr == null || p.timeS <= from || p.timeS > to) continue;
      final dt = p.timeS - points[i - 1].timeS;
      sum += hr * dt;
      weight += dt;
    }
    return weight == 0 ? null : sum / weight;
  }

  double speed(double from, double to) =>
      (track.equivalentAt(track.distanceAtTime(to)) -
          track.equivalentAt(track.distanceAtTime(from))) /
      (to - from);

  final hr1 = meanHr(warmupS, mid), hr2 = meanHr(mid, end);
  if (hr1 == null || hr2 == null) return null;
  final e1 = speed(warmupS, mid) / hr1, e2 = speed(mid, end) / hr2;
  if (e1 <= 0) return null;
  return CardiacDrift(
    percent: (e1 - e2) / e1 * 100,
    firstHalfHeartRate: hr1,
    secondHalfHeartRate: hr2,
    fromS: warmupS,
  );
}

/// Temps passé dans une zone.
class ZoneTime {
  const ZoneTime(this.label, this.seconds);
  final String label;
  final double seconds;
}

/// c) Temps par zone d'allure (% VMA, allure corrigée de la pente).
List<ZoneTime> paceZoneTimes(EffortTrack track, double vmaKmh) {
  const bounds = [
    ('< 60 % (récup, marche)', 0.0),
    ('60–70 % endurance fondamentale', 60.0),
    ('70–80 % endurance active', 70.0),
    ('80–90 % seuil', 80.0),
    ('> 90 % VMA', 90.0),
  ];
  final speeds = track.gapSpeeds();
  final seconds = List.filled(bounds.length, 0.0);
  final points = track.activity.points;
  for (var i = 1; i < points.length; i++) {
    final pct = speeds[i] * 3.6 / vmaKmh * 100;
    var z = 0;
    for (var k = 0; k < bounds.length; k++) {
      if (pct >= bounds[k].$2) z = k;
    }
    seconds[z] += points[i].timeS - points[i - 1].timeS;
  }
  return [
    for (var k = 0; k < bounds.length; k++) ZoneTime(bounds[k].$1, seconds[k]),
  ];
}

/// c) Temps par zone de FC (% de la FC max) : Z1 50–60 … Z5 90–100.
List<ZoneTime> heartRateZoneTimes(CleanActivity activity, int maxHeartRate) {
  const labels = [
    'Z1 < 60 % récupération',
    'Z2 60–70 % endurance',
    'Z3 70–80 % tempo',
    'Z4 80–90 % seuil',
    'Z5 > 90 % maximal',
  ];
  final seconds = List.filled(labels.length, 0.0);
  final points = activity.points;
  for (var i = 1; i < points.length; i++) {
    final hr = points[i].heartRate;
    if (hr == null) continue;
    final pct = hr / maxHeartRate * 100;
    final z = pct < 60 ? 0 : min(4, ((pct - 60) / 10).floor() + 1);
    seconds[z] += points[i].timeS - points[i - 1].timeS;
  }
  return [
    for (var k = 0; k < labels.length; k++) ZoneTime(labels[k], seconds[k]),
  ];
}

/// Part du temps (0–1) au-dessus de l'endurance : zones d'indice ≥ [from].
double shareFrom(List<ZoneTime> zones, int from) {
  final total = zones.fold(0.0, (s, z) => s + z.seconds);
  if (total == 0) return 0;
  return zones.skip(from).fold(0.0, (s, z) => s + z.seconds) / total;
}

/// Écart entre les zones et le but de la séance : en endurance et sortie
/// longue, plus de 20 % du temps au-dessus de l'endurance (Z3+ en FC, ou
/// > 80 % VMA en allure) est trop intense. `null` si conforme.
({double share, bool byHeartRate})? zoneMismatch({
  required SessionType type,
  List<ZoneTime>? heartRateZones,
  List<ZoneTime>? paceZones,
}) {
  if (type != SessionType.endurance && type != SessionType.long) return null;
  if (heartRateZones != null) {
    final share = shareFrom(heartRateZones, 2);
    return share > 0.2 ? (share: share, byHeartRate: true) : null;
  }
  if (paceZones != null) {
    final share = shareFrom(paceZones, 3);
    return share > 0.2 ? (share: share, byHeartRate: false) : null;
  }
  return null;
}

/// e) Cadence : moyenne en courant, et évolution en fin de sortie.
class CadenceReport {
  const CadenceReport({
    required this.average,
    required this.start,
    required this.end,
  });

  /// Pas par minute en courant (marche exclue).
  final double average;

  /// Moyenne de la 1re moitié.
  final double start;

  /// Moyenne des derniers 20 % du temps.
  final double end;

  /// > 0 : chute en fin de sortie (%).
  double get dropPercent => (start - end) / start * 100;

  /// Au-delà de 3 % : signe de fatigue.
  bool get significantDrop => dropPercent >= 3;
}

CadenceReport? cadenceReport(CleanActivity activity) {
  if (!activity.hasCadence) return null;
  final total = activity.movingS;
  double? mean(double from, double to) {
    var sum = 0.0, n = 0;
    for (final p in activity.points) {
      final c = p.cadence;
      // Sous 140 pas/min, on marche : hors analyse de la foulée.
      if (c == null || c < 140 || p.timeS < from || p.timeS > to) continue;
      sum += c;
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  final average = mean(0, total), start = mean(0, total / 2);
  final end = mean(total * 0.8, total);
  if (average == null || start == null || end == null) return null;
  return CadenceReport(average: average, start: start, end: end);
}
