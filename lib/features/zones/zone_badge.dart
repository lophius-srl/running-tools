import 'package:flutter/material.dart';

import '../../domain/zones/zones.dart';

/// Couleur d'une zone : la même partout dans l'app. Du gris (facile) au
/// rouge (très dur) ; texte blanc lisible sur chacune.
Color zoneColor(ZoneId zone) => switch (zone) {
  ZoneId.z1 => const Color(0xFF64748B),
  ZoneId.z2 => const Color(0xFF2563EB),
  ZoneId.z3 => const Color(0xFF15803D),
  ZoneId.z4 => const Color(0xFFB45309),
  ZoneId.z5 => const Color(0xFFDC2626),
};

/// Badge de zone : couleur + Zx, et l'allure et / ou la FC de la zone.
class ZoneBadge extends StatelessWidget {
  const ZoneBadge({
    super.key,
    required this.zone,
    this.zones,
    this.showPace = true,
    this.showHeartRate = true,
  });

  final ZoneId zone;

  /// Zones calculées ; sans elles, seul « Zx » est affiché.
  final ZoneSet? zones;
  final bool showPace;
  final bool showHeartRate;

  @override
  Widget build(BuildContext context) {
    final z = zones?[zone];
    final pace = showPace && z != null ? paceRange(z) : null;
    final bpm = showHeartRate && z != null ? bpmRange(z) : null;
    final detail = [
      if (pace != null) '$pace/km',
      if (bpm != null) '$bpm bpm',
    ].join(' · ');
    final color = zoneColor(zone);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
            child: Text(
              zone.short,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (detail.isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
