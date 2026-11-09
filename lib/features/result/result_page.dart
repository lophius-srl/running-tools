import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../data/providers.dart';
import '../../domain/staged_outcome.dart';
import '../../domain/staged_test_setup.dart';
import '../../domain/test_record.dart';
import '../../domain/test_results.dart';
import '../../domain/timed_test.dart';
import '../../domain/training_paces.dart';
import '../common/decimal_text.dart';
import '../home/home_entry.dart';

typedef RecordBuilder = TestRecord Function(
  TestResult result, {
  required bool prorata,
  required String? shoes,
  required DateTime date,
});

/// Résultat d'un test : VMA, VO2max, allures, setup, puis enregistrement.
class ResultPage extends ConsumerStatefulWidget {
  const ResultPage({
    super.key,
    required this.entry,
    required this.resultFor,
    required this.details,
    required this.setupLines,
    required this.recordFor,
    this.offerProrata = false,
    this.noResultMessage = '',
  });

  /// Résultat d'un test par paliers, avec option prorata.
  factory ResultPage.staged(StagedOutcome outcome, StagedTestSetup setup) {
    final percent = (outcome.fractionOfNextStage * 100).round();
    final p = outcome.protocol;
    return ResultPage(
      entry: HomeEntry.ofStagedTest(outcome.test),
      resultFor: (prorata) => outcome.result(prorata: prorata),
      offerProrata: true,
      details: [
        if (outcome.hasResult)
          'Palier ${outcome.completedStages} complet, '
              'palier suivant couru à $percent %',
        '${outcome.distanceM.round()} m parcourus',
      ],
      setupLines: [
        'Repères tous les ${formatDecimal(p.markerSpacingM)} m '
            '(${setup.method.label.toLowerCase()})',
        'Départ ${formatKmh(p.startSpeedKmh)} km/h, '
            '+${formatKmh(p.incrementKmh)} km/h toutes les '
            '${formatDecimal(p.stageSeconds)} s',
      ],
      noResultMessage:
          'Le premier palier doit être terminé pour calculer un résultat.',
      recordFor: (result, {required prorata, required shoes, required date}) =>
          TestRecord(
            id: '${date.microsecondsSinceEpoch}',
            date: date,
            kind: TestKind.ofStaged(outcome.test),
            vmaKmh: result.vmaKmh,
            vo2max: result.vo2max,
            distanceM: outcome.distanceM,
            completedStages: outcome.completedStages,
            fractionOfNextStage: outcome.fractionOfNextStage,
            prorata: prorata,
            protocol: p,
            method: setup.method,
            shoes: shoes,
          ),
    );
  }

  /// Résultat d'un test chronométré à partir de la distance saisie.
  factory ResultPage.timed(TimedTest test, double distanceM) => ResultPage(
    entry: HomeEntry.ofTimedTest(test),
    resultFor: (_) => test.result(distanceM),
    details: [
      '${formatDecimal(distanceM)} m en ${test.duration.inMinutes} min',
    ],
    setupLines: const [],
    recordFor: (result, {required prorata, required shoes, required date}) =>
        TestRecord(
          id: '${date.microsecondsSinceEpoch}',
          date: date,
          kind: TestKind.ofTimed(test),
          vmaKmh: result.vmaKmh,
          vo2max: result.vo2max,
          distanceM: distanceM,
          shoes: shoes,
        ),
  );

  final HomeEntry entry;
  final TestResult? Function(bool prorata) resultFor;
  final List<String> details;
  final List<String> setupLines;
  final RecordBuilder recordFor;
  final bool offerProrata;
  final String noResultMessage;

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  final _shoes = TextEditingController();
  var _prorata = false;
  var _saving = false;

  @override
  void dispose() {
    _shoes.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _save(TestResult result) async {
    setState(() => _saving = true);
    final shoes = _shoes.text.trim();
    final record = widget.recordFor(
      result,
      prorata: _prorata,
      shoes: shoes.isEmpty ? null : shoes,
      date: DateTime.now(),
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final history = await ref.read(historyRepositoryProvider.future);
      await history.add(record);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Test enregistré')));
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text("Échec de l'enregistrement : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.resultFor(_prorata);
    final bodyLarge = theme.textTheme.bodyLarge;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(entry: widget.entry, result: result),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result == null)
                  Text(widget.noResultMessage, style: bodyLarge),
                for (final line in widget.details) Text(line, style: bodyLarge),
                for (final line in widget.setupLines)
                  Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (result != null && widget.offerProrata)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prorata du palier entamé'),
                    value: _prorata,
                    onChanged: (v) => setState(() => _prorata = v),
                  ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  _PacesCard(vmaKmh: result.vmaKmh),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _shoes,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Chaussures (facultatif)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(result),
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _close,
                    child: const Text('Ignorer'),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _close,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Terminer'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.result});

  final HomeEntry entry;
  final TestResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: entry.gradient,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 8),
              if (result == null)
                Text(
                  'Aucun palier complet',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else ...[
                Text(
                  'VMA ${formatKmh(result.vmaKmh)} km/h',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'VO2max ${formatDecimal(_round1(result.vo2max))} ml/kg/min',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Allures d'entraînement par zone (% VMA → min/km).
class _PacesCard extends StatelessWidget {
  const _PacesCard({required this.vmaKmh});

  final double vmaKmh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Allures d'entraînement",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final pace in trainingPaces(vmaKmh))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pace.zone.name),
                          Text(
                            '${formatDecimal(pace.zone.minPercent)}–'
                            '${formatDecimal(pace.zone.maxPercent)} % VMA',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${formatPace(pace.slowestPace)} – '
                      '${formatPace(pace.fastestPace)} /km',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

double _round1(double v) => (v * 10).round() / 10;
