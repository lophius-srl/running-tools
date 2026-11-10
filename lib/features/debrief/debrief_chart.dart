import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/debrief/debrief_series.dart';
import '../../domain/training_paces.dart';

/// Un moment clé marqué sur le graphique.
typedef ChartMarker = ({double km, String label});

/// Altitude, allure et FC empilées sur la même distance : un graphique par
/// mesure (pas de double axe), moments clés marqués sur les trois.
class DebriefChart extends StatelessWidget {
  const DebriefChart({super.key, required this.series, required this.markers});

  final List<SeriesPoint> series;
  final List<ChartMarker> markers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final hasElevation = series.any((p) => p.elevationM != null);
    final hasHr = series.any((p) => p.heartRate != null);
    final paced = [
      for (final p in series)
        if (p.paceS > 0) p,
    ];
    final panels = <Widget>[
      if (hasElevation)
        _Panel(
          title: 'Altitude (m)',
          color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          spots: [
            for (final p in series)
              if (p.elevationM != null) FlSpot(p.km, p.elevationM!),
          ],
          markers: markers,
          showMarkerLabels: true,
          area: true,
          format: (v) => '${v.round()}',
        ),
      if (paced.isNotEmpty)
        _Panel(
          title: 'Allure (/km)',
          color: dark ? const Color(0xFF6EA0FF) : const Color(0xFF1E63E9),
          // Allure inversée : plus haut = plus rapide, comme on le ressent.
          spots: [for (final p in paced) FlSpot(p.km, -min(p.paceS, 720.0))],
          markers: markers,
          showMarkerLabels: !hasElevation,
          format: (v) => formatPace(Duration(seconds: (-v).round())),
        ),
      if (hasHr)
        _Panel(
          title: 'Fréquence cardiaque (bpm)',
          color: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
          spots: [
            for (final p in series)
              if (p.heartRate != null) FlSpot(p.km, p.heartRate!),
          ],
          markers: markers,
          format: (v) => '${v.round()}',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < panels.length; i++)
          _withAxis(panels[i], bottom: i == panels.length - 1),
        // Légende des moments clés : numéros sur le graphique, texte ici
        // (les étiquettes se chevauchaient quand deux moments étaient
        // proches).
        if (markers.isNotEmpty)
          Text(
            [
              for (var i = 0; i < markers.length; i++)
                '${i + 1} ${markers[i].label} (km '
                    '${markers[i].km.toStringAsFixed(1).replaceAll('.', ',')})',
            ].join('  ·  '),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _withAxis(Widget panel, {required bool bottom}) =>
      _PanelFrame(showBottom: bottom, child: panel);
}

class _PanelFrame extends InheritedWidget {
  const _PanelFrame({required this.showBottom, required super.child});

  final bool showBottom;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelFrame>()?.showBottom ??
      true;

  @override
  bool updateShouldNotify(_PanelFrame old) => old.showBottom != showBottom;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.color,
    required this.spots,
    required this.markers,
    required this.format,
    this.showMarkerLabels = false,
    this.area = false,
  });

  final String title;
  final Color color;
  final List<FlSpot> spots;
  final List<ChartMarker> markers;
  final String Function(double) format;
  final bool showMarkerLabels;
  final bool area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showBottom = _PanelFrame.of(context);
    final ys = spots.map((s) => s.y);
    final low = ys.reduce(min), high = ys.reduce(max);
    final pad = max((high - low) * 0.12, 2.0);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final maxX = spots.last.x;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          SizedBox(
            height: showBottom ? 110 : 86,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: low - pad,
                maxY: high + pad,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: (high - low + 2 * pad) / 2,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      // Seulement la valeur du milieu et les deux lignes :
                      // pas de bornes qui se chevauchent.
                      minIncluded: false,
                      maxIncluded: false,
                      interval: (high - low + 2 * pad) / 2,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(format(v), style: muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: showBottom,
                      reservedSize: 22,
                      interval: max(1, (maxX / 5).ceilToDouble()),
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text('${v.round()} km', style: muted),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    for (final (i, m) in markers.indexed)
                      VerticalLine(
                        x: m.km,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                        label: VerticalLineLabel(
                          show: showMarkerLabels,
                          alignment: Alignment.topRight,
                          style: muted?.copyWith(fontWeight: FontWeight.w700),
                          labelResolver: (_) => '${i + 1}',
                        ),
                      ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItems: (touched) => [
                      for (final t in touched)
                        LineTooltipItem(
                          '${format(t.y)} · '
                          '${t.x.toStringAsFixed(1).replaceAll('.', ',')} km',
                          TextStyle(color: scheme.onInverseSurface),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: area,
                      color: color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
