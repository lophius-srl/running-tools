import 'dart:math';

import 'package:flutter/material.dart';

/// État d'un bouton de la grille.
enum TapState { ready, done, disabled }

class TapGridItem {
  const TapGridItem({
    required this.label,
    this.detail,
    this.state = TapState.ready,
  });

  final String label;

  /// Ligne d'information sous le nom (ex. « Tour 3 · 1:21,4 »).
  final String? detail;
  final TapState state;
}

/// Grille de gros boutons, un par coureur : utilisable en courant, en
/// extérieur, mains moites (cibles d'au moins 96 pt, contraste élevé).
class TapGrid extends StatelessWidget {
  const TapGrid({super.key, required this.items, required this.onTap});

  final List<TapGridItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final columns = items.length <= 4 ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = (items.length / columns).ceil();
        // Les boutons remplissent la hauteur disponible, 96 pt au minimum.
        final height = max(
          96.0,
          (constraints.maxHeight - 8 * (rows - 1)) / rows,
        );
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio:
              (constraints.maxWidth - 8 * (columns - 1)) / columns / height,
          children: [
            for (var i = 0; i < items.length; i++)
              _TapButton(item: items[i], onTap: () => onTap(i)),
          ],
        );
      },
    );
  }
}

class _TapButton extends StatelessWidget {
  const _TapButton({required this.item, required this.onTap});

  final TapGridItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (item.state) {
      TapState.ready => (scheme.primary, scheme.onPrimary),
      TapState.done => (const Color(0xFF15803D), Colors.white),
      TapState.disabled => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.state == TapState.ready ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (item.detail case final detail?)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    detail,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
