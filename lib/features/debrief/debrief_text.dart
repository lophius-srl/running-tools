import '../../domain/course_profile.dart';
import '../../domain/debrief/pacing_analysis.dart';
import '../../domain/debrief/session_type.dart';
import '../common/decimal_text.dart';

/// « 2 min 04 », « 35 s ».
String spokenDuration(double seconds) {
  final s = seconds.round().abs();
  if (s < 60) return '$s s';
  final rest = s % 60;
  return rest == 0
      ? '${s ~/ 60} min'
      : '${s ~/ 60} min ${rest.toString().padLeft(2, '0')}';
}

String _km(double m) =>
    formatDecimal(double.parse((m / 1000).toStringAsFixed(1)));

/// Un constat de l'« En bref », avec son poids (secondes en jeu, environ)
/// pour classer.
class Finding {
  const Finding(this.text, this.impactS, {this.positive = false});

  final String text;
  final double impactS;
  final bool positive;
}

/// Les 3 constats qui comptent le plus, en phrases simples.
List<Finding> keyFindings({
  required PacingAnalysis pacing,
  required List<HillReport> hills,
  required VmaComparison? vma,
  required SessionType type,
}) {
  final findings = <Finding>[];
  final steady = type != SessionType.interval;

  if (steady && (pacing.fastStartPercent ?? 0) > 5) {
    final pct = pacing.fastStartPercent!;
    findings.add(
      Finding(
        'Tu es parti trop vite : tes 3 premiers km étaient ${pct.round()} % '
        'plus rapides que le reste.',
        pct / 100 * 3 * pacing.averageGapPaceS,
      ),
    );
  }
  if (steady && pacing.splitDeltaS > 30) {
    findings.add(
      Finding(
        'Tu as ralenti en 2e partie : ${spokenDuration(pacing.splitDeltaS)} '
        'de plus que la 1re moitié.',
        pacing.splitDeltaS / 2,
      ),
    );
  }
  for (final h in hills) {
    final after = h.afterSlowdownS ?? 0;
    if (h.section.kind == SectionKind.climb && h.lostS < -15 && after > 10) {
      final hr = h.peakHeartRate == null ? '' : ' (FC ${h.peakHeartRate})';
      findings.add(
        Finding(
          'Trop forcé dans la côte du km ${_km(h.section.startM)}$hr, payé '
          'ensuite : ${after.round()} s plus lent par km sur les 2 km suivants.',
          after * 2,
        ),
      );
    }
    if (h.section.kind == SectionKind.descent && h.lostS > 20) {
      findings.add(
        Finding(
          'Tu as perdu ${spokenDuration(h.lostS)} dans la descente du km '
          '${_km(h.section.startM)} : laisse-toi davantage aller.',
          h.lostS,
        ),
      );
    }
  }
  if (vma != null &&
      vma.verdict == VmaVerdict.fast &&
      (type == SessionType.endurance || type == SessionType.long)) {
    findings.add(
      Finding(
        'Trop rapide pour une ${type.label.toLowerCase()} : '
        '${vma.percent.round()} % de ta VMA, vise '
        '${vma.expected.low.round()} à ${vma.expected.high.round()} %.',
        // Pas de temps en jeu, mais c'est le but de la séance : en tête.
        600,
      ),
    );
  }
  findings.sort((a, b) => b.impactS.compareTo(a.impactS));
  if (findings.isEmpty) {
    return [
      const Finding(
        'Sortie bien gérée : allure régulière, rien de notable à corriger.',
        0,
        positive: true,
      ),
    ];
  }
  return findings.take(3).toList();
}

/// Phrase du temps gagnable, ou `null` (fractionné).
String? gainableText(double? gainableS) {
  if (gainableS == null) return null;
  if (gainableS < 5) {
    return 'Effort bien réparti : courir plus régulièrement n’aurait '
        'presque rien changé.';
  }
  return 'En gardant le même effort du début à la fin, tu aurais pu gagner '
      'environ ${spokenDuration(gainableS)} (estimation).';
}

/// Allure : constats en phrases simples.
List<String> pacingLines(PacingAnalysis p, SessionType type) {
  final delta = p.splitDeltaS;
  return [
    if (delta.abs() < 10)
      'Tes deux moitiés ont pris le même temps : bien.'
    else if (delta > 0)
      'Tu as ralenti : ta 2e moitié a pris ${spokenDuration(delta)} de plus '
          'que la 1re.'
    else
      'Tu as accéléré : ta 2e moitié a pris ${spokenDuration(delta)} de '
          'moins que la 1re.',
    if (p.fastStartPercent case final f? when f > 5)
      'Départ trop rapide : 3 premiers km ${f.round()} % plus vite que la '
          'suite.',
    if (p.irregularity case final cv? when type != SessionType.interval)
      cv > 0.05
          ? 'Rythme irrégulier : ton allure a varié d’environ '
                '${(cv * 100).round()} % d’un km à l’autre, côtes comprises.'
          : 'Rythme régulier d’un km à l’autre, côtes comprises.',
  ];
}

/// Une côte ou une descente, en une phrase.
String hillLine(HillReport h) {
  final s = h.section;
  final climb = s.kind == SectionKind.climb;
  final where = climb
      ? 'Côte du km ${_km(s.startM)} au km ${_km(s.endM)} (+${h.gain.round()} m)'
      : 'Descente du km ${_km(s.startM)} au km ${_km(s.endM)} '
            '(−${h.loss.round()} m)';
  final hr = h.peakHeartRate == null ? '' : ', FC max ${h.peakHeartRate}';
  final after = h.afterSlowdownS ?? 0;
  if (climb && h.lostS < -15 && after > 10) {
    return '$where : tu as poussé fort$hr, et tu as ralenti ensuite '
        '(+${after.round()} s/km sur 2 km).';
  }
  if (climb && h.lostS < -15) {
    return '$where : montée vite$hr, sans le payer après.';
  }
  if (h.lostS > 15) {
    return '$where : ${spokenDuration(h.lostS)} de plus qu’à effort '
        'régulier${climb ? '' : ' : tu as retenu'}$hr.';
  }
  return '$where : bien gérée$hr.';
}

/// Intensité comparée à la VMA, en une phrase.
String vmaLine(VmaComparison? c, double? vmaKmh, SessionType type) {
  if (vmaKmh == null) return 'Fais un test de VMA pour comparer ta sortie.';
  if (c == null) return 'Pas de comparaison pour le fractionné.';
  final what = type == SessionType.race
      ? 'une course de cette durée'
      : 'une ${type.label.toLowerCase()}';
  final range = '${c.expected.low.round()} à ${c.expected.high.round()} %';
  final verdict = switch (c.verdict) {
    VmaVerdict.inRange => 'c’est bon',
    VmaVerdict.fast => 'c’était trop vite',
    VmaVerdict.slow => 'c’était plus lent que prévu',
  };
  return 'Tu as couru à ${c.percent.round()} % de ta VMA '
      '(${formatDecimal(vmaKmh)} km/h), côtes comprises. Pour $what, vise '
      '$range : $verdict.';
}
