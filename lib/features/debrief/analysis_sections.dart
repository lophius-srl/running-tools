import 'package:flutter/material.dart';

import '../../domain/course_profile.dart';
import '../../domain/debrief/cardio_analysis.dart';
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
    this.warning,
  });

  final List<Finding> findings;
  final String? gainable;

  /// Réserve sur les données (FC douteuse…).
  final String? warning;

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
            if (warning case final w?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// b) Dérive cardiaque et fiabilité de la FC.
class HeartTile extends StatelessWidget {
  const HeartTile({super.key, required this.quality, required this.driftText});

  final HeartRateQuality quality;
  final String driftText;

  @override
  Widget build(BuildContext context) {
    final reliable = quality.reliable;
    return AnalysisTile(
      title: 'Ton cœur',
      summary: reliable
          ? driftText
          : 'FC peu fiable sur cette sortie : pas de conclusion cardio.',
      children: [
        if (!reliable) ...[
          const Text('Ce qui ne va pas :'),
          for (final i in quality.issues) Text('• ${heartRateIssueText(i)}'),
          const SizedBox(height: 8),
          const Text(
            'Une ceinture cardio est plus fiable qu’un capteur au poignet, '
            'surtout en fractionné et par temps froid.',
          ),
        ] else
          const Text(
            'Dérive : à vitesse égale (côtes comprises), combien ta FC monte '
            'entre la 1re et la 2e moitié, échauffement de 10 min retiré. '
            'Au-delà de 5 %, la fatigue, la chaleur ou le manque d’eau '
            'jouent.',
          ),
      ],
    );
  }
}

/// c) Temps par zone.
class ZonesTile extends StatelessWidget {
  const ZonesTile({
    super.key,
    required this.summary,
    this.heartRateZones,
    this.paceZones,
    this.maxHeartRate,
    this.onEditMaxHeartRate,
  });

  final String summary;
  final List<ZoneTime>? heartRateZones;
  final List<ZoneTime>? paceZones;
  final int? maxHeartRate;
  final VoidCallback? onEditMaxHeartRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bars(String title, List<ZoneTime> zones) {
      final total = zones.fold(0.0, (s, z) => s + z.seconds);
      // Une seule teinte, de clair à foncé : l'intensité monte.
      const ramp = [
        Color(0xFFBFD4FB),
        Color(0xFF8FB3F7),
        Color(0xFF5B8DF0),
        Color(0xFF2F68E0),
        Color(0xFF0B2A6F),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (var i = 0; i < zones.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      zones[i].label,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : zones[i].seconds / total,
                      minHeight: 10,
                      color: ramp[i % ramp.length],
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      total == 0
                          ? '–'
                          : '${(zones[i].seconds / total * 100).round()} %',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      );
    }

    return AnalysisTile(
      title: 'Tes zones',
      summary: summary,
      children: [
        if (heartRateZones case final z?) bars('Fréquence cardiaque', z),
        if (paceZones case final z?)
          bars('Allure (en % de ta VMA, côtes comprises)', z),
        if (maxHeartRate != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'FC max retenue : $maxHeartRate bpm (la plus haute vue dans '
                  'tes sorties).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: onEditMaxHeartRate,
                child: const Text('Modifier'),
              ),
            ],
          ),
      ],
    );
  }
}

/// e) Cadence et fatigue.
class CadenceTile extends StatelessWidget {
  const CadenceTile({super.key, required this.report});

  final CadenceReport report;

  @override
  Widget build(BuildContext context) => AnalysisTile(
    title: 'Ta foulée',
    summary: cadenceLine(report),
    children: [
      Text(
        '1re moitié : ${report.start.round()} pas/min · fin de sortie : '
        '${report.end.round()} pas/min. La marche (sous 140 pas/min) est '
        'exclue.',
      ),
    ],
  );
}
