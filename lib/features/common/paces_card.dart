import 'package:flutter/material.dart';

import '../../domain/training_paces.dart';
import 'decimal_text.dart';

/// Allures d'entraînement par zone (% VMA → min/km).
class PacesCard extends StatelessWidget {
  const PacesCard({super.key, required this.vmaKmh});

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
