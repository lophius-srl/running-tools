import 'package:flutter/material.dart';

import '../../audio/announcements.dart';
import '../../domain/staged_outcome.dart';
import '../common/decimal_text.dart';
import '../home/home_entry.dart';

/// Résultat d'un test par paliers (version minimale ; allures et
/// enregistrement viennent avec l'écran de résultat complet).
class StagedResultPage extends StatefulWidget {
  const StagedResultPage({super.key, required this.outcome});

  final StagedOutcome outcome;

  @override
  State<StagedResultPage> createState() => _StagedResultPageState();
}

class _StagedResultPageState extends State<StagedResultPage> {
  var _prorata = false;

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final theme = Theme.of(context);
    final entry = HomeEntry.ofStagedTest(outcome.test);
    final result = outcome.result(prorata: _prorata);
    final percent = (outcome.fractionOfNextStage * 100).round();

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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.test.label,
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  result == null
                      ? 'Le premier palier doit être terminé pour calculer '
                            'un résultat.'
                      : 'Palier ${outcome.completedStages} complet, '
                            'palier suivant couru à $percent %.',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  '${outcome.distanceM.round()} m parcourus',
                  style: theme.textTheme.bodyLarge,
                ),
                if (result != null)
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
