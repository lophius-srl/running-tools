import 'package:flutter/material.dart';

/// Rangée de gros boutons de couloir (1 à [lanes]).
class LaneSelector extends StatelessWidget {
  const LaneSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.lanes = 8,
  });

  final int lanes;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var lane = 1; lane <= lanes; lane++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _LaneButton(
                lane: lane,
                selected: selected == lane,
                onTap: () => onChanged(lane),
              ),
            ),
          ),
      ],
    );
  }
}

/// Gros bouton de couloir, facile à viser en extérieur.
class _LaneButton extends StatelessWidget {
  const _LaneButton({
    required this.lane,
    required this.selected,
    required this.onTap,
  });

  final int lane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Couloir $lane',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                '$lane',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
