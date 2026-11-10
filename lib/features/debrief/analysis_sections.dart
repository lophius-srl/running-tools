import 'package:flutter/material.dart';

import '../../domain/course_profile.dart';
import '../../domain/debrief/pacing_analysis.dart';
import '../../domain/debrief/session_type.dart';
import '../../domain/training_paces.dart';
import '../course/course_text.dart';
import 'debrief_text.dart';

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
  const PacingTile({super.key, required this.pacing, required this.type});

  final PacingAnalysis pacing;
  final SessionType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = pacingLines(pacing, type);
    return AnalysisTile(
      title: 'Ton allure',
      summary: lines.first,
      children: [
        for (final l in lines.skip(1))
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l)),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(0.5)},
          children: [
            TableRow(
              children: [
                for (final h in ['Km', 'Allure', 'Si plat', 'Relief'])
                  Text(h, style: theme.textTheme.labelMedium),
              ],
            ),
            for (final s in pacing.splits)
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
                    s.elevationDeltaM.abs() < 3
                        ? 'plat'
                        : '${s.elevationDeltaM > 0 ? '+' : '−'}'
                              '${s.elevationDeltaM.abs().round()} m',
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '« Si plat » : ton allure si le km avait été plat. Une côte '
          'ralentit, une descente aide : cette colonne montre ton effort '
          'réel.',
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
    final climbs = hills
        .where((h) => h.section.kind == SectionKind.climb)
        .length;
    final descents = hills.length - climbs;
    return AnalysisTile(
      title: 'Les côtes',
      summary: hills.isEmpty
          ? 'Parcours plat : rien à signaler.'
          : '$climbs côte${climbs > 1 ? 's' : ''}, $descents '
                'descente${descents > 1 ? 's' : ''}.',
      children: [
        for (final h in hills)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(hillLine(h)),
          ),
      ],
    );
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
  Widget build(BuildContext context) => AnalysisTile(
    title: 'Ton intensité',
    summary: vmaLine(comparison, vmaKmh, type),
    children: const [
      Text(
        'Repères : endurance et sortie longue 60 à 75 % de ta VMA ; en '
        'course, de 95 % sur 10 min à 75 % sur 3 h.',
      ),
    ],
  );
}

/// L'essentiel en haut du débrief.
class KeyFindingsCard extends StatelessWidget {
  const KeyFindingsCard({
    super.key,
    required this.findings,
    required this.gainable,
  });

  final List<Finding> findings;
  final String? gainable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'En bref',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final f in findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      f.positive ? Icons.check_circle : Icons.lightbulb,
                      size: 20,
                      color: f.positive
                          ? const Color(0xFF15803D)
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.text)),
                  ],
                ),
              ),
            if (gainable case final g?)
              Text(
                g,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
