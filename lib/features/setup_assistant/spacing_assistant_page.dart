import 'package:flutter/material.dart';

import '../../domain/marker_spacing.dart';
import '../../domain/measurement_method.dart';
import '../common/decimal_text.dart';

/// Assistant de mise en place : choisir comment obtenir l'espacement des
/// repères. Renvoie un [SpacingChoice] via `Navigator.pop`.
class SpacingAssistantPage extends StatefulWidget {
  const SpacingAssistantPage({super.key});

  @override
  State<SpacingAssistantPage> createState() => _SpacingAssistantPageState();
}

enum _Method { manual, field }

class _SpacingAssistantPageState extends State<SpacingAssistantPage> {
  _Method? _open;
  final _manual = TextEditingController();

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _choose(SpacingChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final manual = parseDecimal(_manual.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Mise en place des repères')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Choisis comment obtenir l'espacement entre deux repères.",
          ),
          const SizedBox(height: 12),
          _MethodCard(
            icon: Icons.edit,
            title: 'Saisie manuelle',
            subtitle: 'Distance mesurée au décamètre ou connue',
            expanded: _open == _Method.manual,
            onTap: () => setState(() => _open = _Method.manual),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Espacement',
                      suffixText: 'm',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: manual != null && manual > 0
                      ? () => _choose(
                          SpacingChoice(manual, MeasurementMethod.tape),
                        )
                      : null,
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
          _MethodCard(
            icon: Icons.sports_soccer,
            title: 'Terrain normé',
            subtitle: 'Utiliser les lignes d’un terrain de sport',
            expanded: _open == _Method.field,
            onTap: () => setState(() => _open = _Method.field),
            child: Column(
              children: [
                for (final f in StandardField.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label),
                    subtitle: Text(f.howTo),
                    trailing: Text(
                      '${formatDecimal(f.spacingM)} m',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _choose(
                      SpacingChoice(
                        f.spacingM,
                        MeasurementMethod.field,
                        source: f.label,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const _MethodCard(
            icon: Icons.do_not_step,
            title: 'Chaussure (talon-pointe)',
            subtitle: 'Bientôt disponible',
          ),
          const _MethodCard(
            icon: Icons.view_in_ar,
            title: 'Réalité augmentée',
            subtitle: 'Bientôt disponible',
          ),
        ],
      ),
    );
  }
}

/// Carte d'une méthode ; se déplie pour afficher [child]. Sans [onTap], elle
/// est grisée (méthode pas encore disponible).
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.expanded = false,
    this.onTap,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            enabled: onTap != null,
            leading: Icon(icon, color: onTap != null ? scheme.primary : null),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            trailing: onTap == null
                ? null
                : Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onTap,
          ),
          if (expanded && child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}
