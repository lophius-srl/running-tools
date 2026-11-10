import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/ghost_repository.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'ghost_page.dart';

/// Bilan : temps comparé au fantôme et courbe de l'écart.
class GhostResultPage extends StatelessWidget {
  const GhostResultPage({super.key, required this.summary});

  final GhostRunSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ahead = summary.gapS >= 0;
    final km = (summary.distanceM / 1000)
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    return Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.ghost, trailing: summary.ghostName),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  ahead ? 'Fantôme battu !' : 'Le fantôme gagne',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GapText(
                    seconds: summary.gapS,
                    style: theme.textTheme.displayMedium,
                  ),
                ),
                Text(
                  '$km km en ${formatClock(summary.timeS)} · fantôme en '
                  '${formatClock(summary.timeS + summary.gapS)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  summary.alignment.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                if (summary.curve.length >= 2) ...[
                  Text(
                    'Écart selon la distance (s, au-dessus : devant)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 220, child: GapChart(curve: summary.curve)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
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

/// Écart (s) selon la distance (km), zéro marqué.
class GapChart extends StatelessWidget {
  const GapChart({super.key, required this.curve});

  final List<(double, double)> curve;

  static const _lineLight = Color(0xFF1E63E9);
  static const _lineDark = Color(0xFF6EA0FF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = theme.brightness == Brightness.dark ? _lineDark : _lineLight;
    final gaps = curve.map((p) => p.$2);
    final extent = max(
      5.0,
      gaps.map((g) => g.abs()).reduce(max),
    ).ceilToDouble();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: curve.last.$1 / 1000,
        minY: -extent,
        maxY: extent,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: extent,
          getDrawingHorizontalLine: (v) => FlLine(
            color: v == 0 ? scheme.onSurfaceVariant : scheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: extent,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(formatGap(value), style: muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: max(1, (curve.last.$1 / 1000 / 5).ceilToDouble()),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.round()} km', style: muted),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${formatGap(s.y)}\n'
                  '${s.x.toStringAsFixed(1).replaceAll('.', ',')} km',
                  TextStyle(color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (d, g) in curve) FlSpot(d / 1000, g)],
            color: line,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
