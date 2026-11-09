import 'package:flutter/material.dart';

/// Comment placer ses repères sur une piste d'athlétisme de 400 m.
/// Renvoie `true` si l'utilisateur retient l'espacement de 20 m.
class TrackGuideSheet extends StatelessWidget {
  const TrackGuideSheet({super.key});

  static const steps = [
    (
      Icons.straighten,
      'Mesurer en couloir 1',
      'Un tour fait 400 m dans le couloir 1, mesuré à 30 cm du bord '
          'intérieur (la lice). Pose tes plots à 30 cm de la lice, surtout '
          'dans les virages.',
    ),
    (
      Icons.flag,
      'Les lignes déjà tracées',
      'En couloir 1, la ligne d’arrivée et les lignes de départ du 300 m, '
          'du 200 m et du 100 m sont espacées de 100 m : un repère tous les '
          '100 m, déjà en place.',
    ),
    (
      Icons.more_horiz,
      '4 plots entre deux lignes',
      'Entre deux de ces lignes, place 4 plots tous les 20 m (décamètre, '
          'pas talon-pointe ou réalité augmentée) : 20 plots par tour.',
    ),
    (
      Icons.swap_horiz,
      'Pour vérifier',
      'Chaque ligne droite mesure 84,39 m, de la fin d’un virage au début '
          'du suivant.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sur une piste de 400 m',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '20 m est l’espacement le plus simple : les plots tombent pile '
              'sur les lignes des 100 m.',
            ),
            const SizedBox(height: 12),
            for (final (icon, title, text) in steps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: theme.colorScheme.primary),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(text),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Utiliser 20 m'),
            ),
          ],
        ),
      ),
    );
  }
}
