import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../domain/test_record.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../home/home_entry.dart';
import 'history_controller.dart';
import 'history_detail_page.dart';
import 'progress_card.dart';

/// Liste des tests enregistrés, du plus récent au plus ancien.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyControllerProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          ...switch (history) {
            AsyncData(value: final records) when records.isEmpty => [
              const SliverFillRemaining(hasScrollBody: false, child: _Empty()),
            ],
            AsyncData(value: final records) => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ProgressCard(records: records),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _RecordCard(
                    key: ValueKey('record-${records[i].id}'),
                    record: records[i],
                  ),
                ),
              ),
            ],
            AsyncError(:final error) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Historique illisible : $error')),
              ),
            ],
            _ => [
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2A6F), Color(0xFF1E63E9), Color(0xFF38B6FF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackButton(color: Colors.white),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Historique',
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Aucun test enregistré', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Fais un test puis touche « Enregistrer » sur le résultat.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({super.key, required this.record});

  final TestRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = HomeEntry.ofKind(record.kind);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryDetailPage(record: record),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: entry.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.kind.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatDateTime(record.date),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatKmh(record.vmaKmh)} km/h',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'VO2max ${formatDecimal(_round1(record.vo2max))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _round1(double v) => (v * 10).round() / 10;
