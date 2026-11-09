import 'package:flutter/material.dart';

import '../../audio/announcements.dart';
import '../../domain/staged_outcome.dart';
import '../../domain/test_results.dart';
import '../../domain/timed_test.dart';
import '../common/decimal_text.dart';
import '../home/home_entry.dart';

/// Résultat d'un test (version minimale ; allures et enregistrement viennent
/// avec l'écran de résultat complet).
class ResultPage extends StatefulWidget {
  const ResultPage({
    super.key,
    required this.entry,
    required this.resultFor,
    required this.details,
    this.offerProrata = false,
    this.noResultMessage = '',
  });

  /// Résultat d'un test par paliers, avec option prorata.
  factory ResultPage.staged(StagedOutcome outcome) {
    final percent = (outcome.fractionOfNextStage * 100).round();
    return ResultPage(
      entry: HomeEntry.ofStagedTest(outcome.test),
      resultFor: (prorata) => outcome.result(prorata: prorata),
      offerProrata: true,
      details: [
        if (outcome.hasResult)
          'Palier ${outcome.completedStages} complet, '
              'palier suivant couru à $percent %.',
        '${outcome.distanceM.round()} m parcourus',
      ],
      noResultMessage:
          'Le premier palier doit être terminé pour calculer un résultat.',
    );
  }

  /// Résultat d'un test chronométré à partir de la distance saisie.
  factory ResultPage.timed(TimedTest test, double distanceM) => ResultPage(
    entry: HomeEntry.ofTimedTest(test),
    resultFor: (_) => test.result(distanceM),
    details: [
      '${formatDecimal(distanceM)} m en ${test.duration.inMinutes} min',
    ],
  );

  final HomeEntry entry;
  final TestResult? Function(bool prorata) resultFor;
  final List<String> details;
  final bool offerProrata;
  final String noResultMessage;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  var _prorata = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.resultFor(_prorata);
    final white = theme.textTheme.titleLarge?.copyWith(color: Colors.white);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.entry.gradient,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.label,
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
                        'VO2max ${formatDecimal(_round1(result.vo2max))} '
                        'ml/kg/min',
                        style: white,
                      ),
                    ],
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
                if (result == null)
                  Text(
                    widget.noResultMessage,
                    style: theme.textTheme.bodyLarge,
                  ),
                for (final line in widget.details)
                  Text(line, style: theme.textTheme.bodyLarge),
                if (result != null && widget.offerProrata)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prorata du palier entamé'),
                    value: _prorata,
                    onChanged: (v) => setState(() => _prorata = v),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Terminer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _round1(double v) => (v * 10).round() / 10;
