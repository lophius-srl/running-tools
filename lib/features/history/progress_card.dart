import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/progression.dart';
import '../../domain/test_record.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';

/// Couleur de la courbe (validée pour chaque fond, clair et sombre).
const _lineLight = Color(0xFF1E63E9);
const _lineDark = Color(0xFF3D8EF0);

/// Graphe de progression : une seule série, filtrable par test.
class ProgressCard extends StatefulWidget {
  const ProgressCard({super.key, required this.records});

  final List<TestRecord> records;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  var _metric = ProgressMetric.vma;
  late Set<TestKind> _kinds = _available;

  Set<TestKind> get _available => {for (final r in widget.records) r.kind};

  @override
  void didUpdateWidget(ProgressCard old) {
    super.didUpdateWidget(old);
    // Après une suppression, on garde la sélection parmi les tests restants.
    _kinds = _kinds.intersection(_available);
    if (_kinds.isEmpty) _kinds = _available;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = progressPoints(
      widget.records,
      metric: _metric,
      kinds: _kinds,
    );
    final available = TestKind.values.where(_available.contains).toList();

    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Progression ${_metric.label} (${_metric.unit})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<ProgressMetric>(
              segments: [
                for (final m in ProgressMetric.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_metric},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) => setState(() => _metric = s.single),
            ),
            if (available.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in available)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(kind.label),
                      selected: _kinds.contains(kind),
                      onSelected: (on) => setState(
                        () => on ? _kinds.add(kind) : _kinds.remove(kind),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: switch (points.length) {
                0 => const Center(child: Text('Aucun test pour ce filtre.')),
                1 => _SinglePoint(point: points.single, metric: _metric),
                _ => _Chart(points: points),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SinglePoint extends StatelessWidget {
  const _SinglePoint({required this.point, required this.metric});

  final ProgressPoint point;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${formatDecimal(point.value)} ${metric.unit}',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Un seul test pour l’instant : refais-en un pour voir ta '
          'progression.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = theme.brightness == Brightness.dark ? _lineDark : _lineLight;
    final first = points.first.date;
    double dayOf(DateTime d) => d.difference(first).inMinutes / 1440;

    final values = points.map((p) => p.value);
    final minY = (values.reduce(min) - 0.5).floorToDouble();
    final maxY = (values.reduce(max) + 0.5).ceilToDouble();
    final lastX = max(dayOf(points.last.date), 1.0);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastX,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        // Les points aux extrémités ne sont pas coupés par le cadre.
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(formatDecimal(value), style: muted),
              ),
            ),
          ),
          // Seulement la première et la dernière date : pas de collision.
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: lastX,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _shortDate(
                    first.add(Duration(minutes: (value * 1440).round())),
                  ),
                  style: muted,
                ),
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
                  '${formatDecimal(s.y)}\n'
                  '${points[s.spotIndex].kind.label} · '
                  '${formatDateTime(points[s.spotIndex].date).split(',').first}',
                  TextStyle(color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final p in points) FlSpot(dayOf(p.date), p.value)],
            color: line,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: line,
                strokeWidth: 2,
                strokeColor: scheme.surfaceContainerLowest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime d) => '${d.day}/${d.month}';
