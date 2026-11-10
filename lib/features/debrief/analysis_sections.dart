import 'package:flutter/material.dart';

import '../../domain/course_profile.dart';
import '../../domain/debrief/pacing_analysis.dart';
import '../../domain/debrief/session_type.dart';
import '../../domain/training_paces.dart';
import '../common/decimal_text.dart';
import '../course/course_text.dart';

/// « 5:12 » pour 312 s/km.
String paceText(double secondsPerKm) =>
    formatPace(Duration(seconds: secondsPerKm.round()));

/// « 1:05 » ou « 35 s ».
String durationText(double seconds) {
  final s = seconds.round().abs();
  return s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '$s s';
}

/// Section repliable d'une analyse.
class AnalysisTile extends StatelessWidget {
  const AnalysisTile({
    super.key,
    required this.title,
    required this.summary,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(summary),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

/// a) Gestion de l'allure.
class PacingTile extends StatelessWidget {
  const PacingTile({super.key, required this.pacing});

  final PacingAnalysis pacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pacing;
    final delta = p.splitDeltaS;
    final split = delta.abs() < 10
        ? 'Moitiés équilibrées (écart ${durationText(delta)}).'
        : delta > 0
        ? 'Split positif : 2e moitié ${durationText(delta)} plus lente.'
        : 'Split négatif : 2e moitié ${durationText(delta)} plus rapide.';
    final lines = <String>[
      split,
      if (p.fastStartPercent case final f? when f > 3)
        'Départ rapide : 3 premiers km ${f.round()} % plus vite que ta '
            'moyenne (allure corrigée de la pente).',
      if (p.irregularity case final cv?)
        'Régularité : ±${formatDecimal(double.parse((cv * 100).toStringAsFixed(1)))} % '
            'd’un km à l’autre (allure corrigée)'
            '${cv > 0.05 ? ', irrégulier' : ''}.',
      if (p.gainableS case final g?)
        g < 5
            ? 'Allure bien répartie : presque rien à gagner.'
            : 'Temps gagnable estimé : environ ${durationText(g)}, à effort '
                  'égal, en courant plus régulièrement.',
    ];
    return AnalysisTile(
      title: 'Allure',
      summary: lines.first,
      initiallyExpanded: true,
      children: [
        for (final l in lines.skip(1))
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l)),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(0.6)},
          children: [
            TableRow(
              children: [
                for (final h in ['km', 'allure', 'corrigée', 'D±'])
                  Text(h, style: theme.textTheme.labelMedium),
              ],
            ),
            for (final s in p.splits)
              TableRow(
                children: [
                  Text(
                    s.lengthM < 900
                        ? formatKm(s.lengthM, decimals: 2)
                        : '${s.index}',
                  ),
                  Text(paceText(s.paceS)),
                  Text(paceText(s.gapPaceS)),
                  Text(
                    '${s.elevationDeltaM >= 0 ? '+' : '−'}'
                    '${s.elevationDeltaM.abs().round()} m',
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Allure corrigée : ce que vaudrait l’effort sur le plat. Le temps '
          'gagnable est une estimation : même effort total, réparti '
          'régulièrement.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// d) Montées et descentes.
class HillsTile extends StatelessWidget {
  const HillsTile({super.key, required this.hills});

  final List<HillReport> hills;

  @override
  Widget build(BuildContext context) {
    final costly = hills.where((h) => h.section.kind == SectionKind.climb);
    final summary = hills.isEmpty
        ? 'Parcours plat : rien à signaler.'
        : '${costly.length} montée(s), ${hills.length - costly.length} '
              'descente(s).';
    return AnalysisTile(
      title: 'Relief',
      summary: summary,
      children: [
        for (final h in hills)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_describe(h)),
          ),
      ],
    );
  }

  static String _km(double m) =>
      (m / 1000).toStringAsFixed(1).replaceAll('.', ',');

  static String _describe(HillReport h) {
    final s = h.section;
    final where =
        '${s.kind.label} du km ${_km(s.startM)} au km ${_km(s.endM)} '
        '(${s.kind == SectionKind.climb ? '+${h.gain.round()}' : '−${h.loss.round()}'} m)';
    final lost = h.lostS.abs() < 5
        ? 'à effort régulier'
        : h.lostS < 0
        ? '${durationText(h.lostS)} plus vite qu’à effort régulier'
        : '${durationText(h.lostS)} de plus qu’à effort régulier';
    final after = switch (h.afterSlowdownS) {
      final a? when a > 5 => ', puis +${a.round()} s/km sur les 2 km suivants',
      _ => '',
    };
    final hr = h.peakHeartRate == null ? '' : ' · FC max ${h.peakHeartRate}';
    return '$where : $lost$hr$after.';
  }
}

/// f) Comparaison avec la VMA.
class VmaTile extends StatelessWidget {
  const VmaTile({
    super.key,
    required this.comparison,
    required this.vmaKmh,
    required this.type,
  });

  final VmaComparison? comparison;
  final double? vmaKmh;
  final SessionType type;

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    final String summary;
    if (vmaKmh == null) {
      summary = 'Fais un test de VMA pour comparer ta sortie.';
    } else if (c == null) {
      summary = 'Pas de comparaison pour le fractionné.';
    } else {
      final range = '${c.expected.low.round()}–${c.expected.high.round()} %';
      summary =
          '${c.percent.round()} % de ta VMA (${formatDecimal(vmaKmh!)} km/h). '
          '${switch (c.verdict) {
            VmaVerdict.inRange => 'Dans la plage habituelle',
            VmaVerdict.fast => 'Plus vite que la plage habituelle',
            VmaVerdict.slow => 'Plus lent que la plage habituelle',
          }} pour ${type == SessionType.race ? 'une course de cette durée' : 'une ${type.label.toLowerCase()}'} ($range).';
    }
    return AnalysisTile(
      title: 'VMA',
      summary: summary,
      children: const [
        Text(
          'Allure corrigée de la pente, en % de ta VMA du dernier test. '
          'Endurance et sortie longue : 60–75 % ; en course, de ~95 % sur '
          '10 min à ~75 % sur 3 h.',
        ),
      ],
    );
  }
}
