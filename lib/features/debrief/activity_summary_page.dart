import 'package:flutter/material.dart';

import '../../domain/debrief/clean_activity.dart';
import '../../domain/debrief/session_type.dart';
import '../../domain/training_paces.dart';
import '../common/date_text.dart';
import '../common/run_widgets.dart';
import '../course/course_text.dart';
import '../home/home_entry.dart';

/// Étape 1 du débrief : ce qui a été lu dans la sortie, et son type.
class ActivitySummaryPage extends StatefulWidget {
  const ActivitySummaryPage({
    super.key,
    required this.activity,
    required this.detected,
  });

  final CleanActivity activity;
  final SessionType detected;

  @override
  State<ActivitySummaryPage> createState() => _ActivitySummaryPageState();
}

class _ActivitySummaryPageState extends State<ActivitySummaryPage> {
  late var _type = widget.detected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.activity;
    final pace = a.averageKmh <= 0
        ? '–'
        : '${formatPace(paceForSpeed(a.averageKmh))}/km';
    final gain = a.profile?.climb().gain.round();
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    Widget stream(String label, bool present) => Chip(
      avatar: Icon(
        present ? Icons.check_circle : Icons.remove_circle_outline,
        color: present ? const Color(0xFF15803D) : theme.colorScheme.outline,
      ),
      label: Text(label),
    );
    return Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.debrief, trailing: a.name),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  formatDateTime(a.start.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                row('Distance', formatKm(a.distanceM, decimals: 2)),
                row('Temps en mouvement', formatRaceTime(a.movingS)),
                row(
                  'Temps total',
                  formatRaceTime(a.elapsed.inSeconds.toDouble()),
                ),
                row('Allure moyenne', pace),
                if (gain != null) row('Dénivelé positif', '$gain m'),
                row(
                  'Pauses retirées',
                  a.pauses.isEmpty
                      ? 'aucune'
                      : '${a.pauses.length} · '
                            '${formatRaceTime(a.pausedTime.inSeconds.toDouble())}',
                ),
                if (a.rejectedFixes > 0)
                  row('Points GPS écartés', '${a.rejectedFixes}'),
                const SizedBox(height: 12),
                Text('Données présentes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    stream('Altitude', a.hasElevation),
                    stream('Fréquence cardiaque', a.hasHeartRate),
                    stream('Cadence', a.hasCadence),
                  ],
                ),
                if (!a.hasHeartRate || !a.hasCadence)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Les analyses qui en dépendent seront masquées.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Type de séance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in SessionType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Détecté : ${widget.detected.label}. Corrige si besoin.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Text(
                  'Les analyses arrivent à l’étape suivante.',
                  textAlign: TextAlign.center,
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
