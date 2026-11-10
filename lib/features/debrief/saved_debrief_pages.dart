import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/debrief/debrief_score.dart';
import '../../domain/debrief/debrief_summary.dart';
import '../common/date_text.dart';
import '../common/run_widgets.dart';
import '../course/course_text.dart';
import '../home/home_entry.dart';
import 'analysis_sections.dart';
import 'debrief_text.dart';

/// Une ligne de comparaison : libellé et valeur de chaque débrief.
typedef _Metric = ({
  String label,
  String Function(DebriefSummary) value,
  double? Function(DebriefSummary) raw,
  bool lowerIsBetter,
});

final _metrics = <_Metric>[
  (
    label: 'Distance',
    value: (d) => formatKm(d.distanceM, decimals: 2),
    raw: (d) => null,
    lowerIsBetter: false,
  ),
  (
    label: 'Temps',
    value: (d) => formatRaceTime(d.movingS),
    raw: (d) => null,
    lowerIsBetter: true,
  ),
  (
    label: 'Allure',
    value: (d) => '${paceText(d.paceS)}/km',
    raw: (d) => d.paceS,
    lowerIsBetter: true,
  ),
  (
    label: 'Allure si plat',
    value: (d) => d.gapPaceS == null ? '–' : '${paceText(d.gapPaceS!)}/km',
    raw: (d) => d.gapPaceS,
    lowerIsBetter: true,
  ),
  (
    label: 'Dénivelé +',
    value: (d) =>
        d.elevationGainM == null ? '–' : '${d.elevationGainM!.round()} m',
    raw: (d) => null,
    lowerIsBetter: false,
  ),
  (
    label: 'Note',
    value: (d) => '${d.score}/100',
    raw: (d) => d.score.toDouble(),
    lowerIsBetter: false,
  ),
  (
    label: 'Temps gagnable',
    value: (d) => d.gainableS == null ? '–' : spokenDuration(d.gainableS!),
    raw: (d) => d.gainableS,
    lowerIsBetter: true,
  ),
  (
    label: 'FC moyenne',
    value: (d) =>
        d.averageHeartRate == null ? '–' : '${d.averageHeartRate!.round()} bpm',
    raw: (d) => d.averageHeartRate,
    lowerIsBetter: true,
  ),
  (
    label: 'Dérive cardiaque',
    value: (d) => d.driftPercent == null ? '–' : '${d.driftPercent!.round()} %',
    raw: (d) => d.driftPercent,
    lowerIsBetter: true,
  ),
  (
    label: 'Cadence',
    value: (d) =>
        d.averageCadence == null ? '–' : '${d.averageCadence!.round()} pas/min',
    raw: (d) => null,
    lowerIsBetter: false,
  ),
  (
    label: 'Intensité',
    value: (d) => d.vmaPercent == null ? '–' : '${d.vmaPercent!.round()} % VMA',
    raw: (d) => null,
    lowerIsBetter: false,
  ),
];

/// Un débrief de l'historique.
class SavedDebriefPage extends ConsumerWidget {
  const SavedDebriefPage({super.key, required this.debrief, required this.all});

  final DebriefSummary debrief;
  final List<DebriefSummary> all;

  Future<void> _compare(BuildContext context) async {
    final others =
        [
          for (final d in all)
            if (d.id != debrief.id) d,
        ]..sort((a, b) {
          final sa = sameRoute(debrief, a) ? 0 : 1;
          final sb = sameRoute(debrief, b) ? 0 : 1;
          return sa != sb ? sa - sb : b.date.compareTo(a.date);
        });
    final other = await showModalBottomSheet<DebriefSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Comparer avec',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final d in others)
              ListTile(
                title: Text(d.name),
                subtitle: Text(
                  '${formatDateTime(d.date.toLocal())} · '
                  '${formatKm(d.distanceM)}'
                  '${sameRoute(debrief, d) ? ' · même parcours' : ''}',
                ),
                trailing: Text('${d.score}/100'),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (other == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompareDebriefsPage(a: debrief, b: other),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = await ref.read(debriefRepositoryProvider.future);
    await repo.delete(debrief.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = debrief;
    return Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.debrief, trailing: d.name),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${formatDateTime(d.date.toLocal())} · ${d.type.label}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ScoreCard(
                  score: DebriefScore(d.score, const {}),
                  gainable: gainableText(d.gainableS),
                ),
                const SizedBox(height: 12),
                KeyFindingsCard(
                  findings: [
                    for (final f in d.findings)
                      Finding(
                        f,
                        0,
                        positive: f.startsWith('Sortie bien gérée'),
                      ),
                  ],
                  gainable: null,
                ),
                for (final m in _metrics)
                  if (m.value(d) != '–')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(m.label)),
                          Text(
                            m.value(d),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: all.length < 2 ? null : () => _compare(context),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Comparer avec une autre sortie'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer ce débrief'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deux débriefs côte à côte.
class CompareDebriefsPage extends StatelessWidget {
  const CompareDebriefsPage({super.key, required this.a, required this.b});

  final DebriefSummary a;
  final DebriefSummary b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Le plus ancien à gauche : on lit la progression.
    final (left, right) = a.date.isBefore(b.date) ? (a, b) : (b, a);
    String day(DebriefSummary d) {
      final l = d.date.toLocal();
      return '${l.day}/${l.month}/${l.year % 100}';
    }

    const better = Color(0xFF15803D);
    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.debrief, trailing: 'Comparaison'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  sameRoute(left, right)
                      ? 'Même parcours : la comparaison est parlante.'
                      : 'Parcours différents : compare avec prudence.',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {0: FlexColumnWidth(1.3)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const SizedBox(),
                        for (final d in [left, right])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${day(d)}\n${d.name}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                      ],
                    ),
                    for (final m in _metrics)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(m.label),
                          ),
                          for (final d in [left, right])
                            () {
                              final other = identical(d, left) ? right : left;
                              final mine = m.raw(d), theirs = m.raw(other);
                              final wins =
                                  mine != null &&
                                  theirs != null &&
                                  mine != theirs &&
                                  (m.lowerIsBetter
                                      ? mine < theirs
                                      : mine > theirs);
                              return Text(
                                m.value(d),
                                style: TextStyle(
                                  fontWeight: wins
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: wins ? better : null,
                                ),
                              );
                            }(),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'En vert : le meilleur des deux. Allure « si plat » et note '
                  'tiennent compte du relief.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
