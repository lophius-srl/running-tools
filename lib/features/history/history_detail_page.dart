import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../domain/test_record.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/paces_card.dart';
import '../home/home_entry.dart';
import 'history_controller.dart';

/// Détail d'un test enregistré : résultat, setup, allures recalculées.
class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({super.key, required this.record});

  final TestRecord record;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce test ?'),
        content: Text(
          '${record.kind.label} du ${formatDateTime(record.date)}. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(historyControllerProvider.notifier).delete(record.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entry = HomeEntry.ofKind(record.kind);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final p = record.protocol;
    final details = [
      ?_stageLine(record),
      if (record.distanceM case final d?) '${d.round()} m parcourus',
    ];
    final setup = [
      if (p != null)
        'Repères tous les ${formatDecimal(p.markerSpacingM)} m'
            '${record.method == null ? '' : ' (${record.method!.label.toLowerCase()})'}',
      if (p != null)
        'Départ ${formatKmh(p.startSpeedKmh)} km/h, '
            '+${formatKmh(p.incrementKmh)} km/h toutes les '
            '${formatDecimal(p.stageSeconds)} s',
      if (record.shoes case final shoes?) 'Chaussures : $shoes',
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: entry.gradient,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BackButton(color: Colors.white),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          onPressed: () => _confirmDelete(context, ref),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.kind.label} · ${formatDateTime(record.date)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'VMA ${formatKmh(record.vmaKmh)} km/h',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'VO2max ${formatDecimal(_round1(record.vo2max))} '
                            'ml/kg/min',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in details)
                  Text(line, style: theme.textTheme.bodyLarge),
                for (final line in setup) Text(line, style: muted),
                const SizedBox(height: 16),
                PacesCard(vmaKmh: record.vmaKmh),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Palier 14 complet, suivant couru à 40 % (prorata) » ; null hors paliers.
String? _stageLine(TestRecord record) {
  final stages = record.completedStages;
  if (stages == null) return null;
  final fraction = record.fractionOfNextStage ?? 0;
  final next = fraction > 0
      ? ', suivant couru à ${(fraction * 100).round()} %'
      : '';
  return 'Palier $stages complet$next${record.prorata ? ' (prorata)' : ''}';
}

double _round1(double v) => (v * 10).round() / 10;
