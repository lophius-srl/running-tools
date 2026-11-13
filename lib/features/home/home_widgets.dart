import 'package:flutter/material.dart';

import '../../app_theme.dart';
import 'home_entry.dart';

/// Ouvre l'écran d'une entrée.
typedef EntryOpener = void Function(HomeEntry entry);

/// En-tête de page commun aux onglets : titre, sous-titre, contenu.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.child,
  });

  final String title;

  /// Petite ligne au-dessus du titre (la date…).
  final String? overline;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = TextStyle(color: Colors.white.withValues(alpha: 0.8));
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.l),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppGradients.header,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.l + 4,
            AppSpace.m,
            AppSpace.l + 4,
            AppSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null) Text(overline!, style: soft),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) Text(subtitle!, style: soft),
              if (child != null) ...[
                const SizedBox(height: AppSpace.l),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie, titre facultatif.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.child,
    this.title,
    this.onTap,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.m),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.m),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ?trailing,
                        if (trailing == null && onTap != null)
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile d'un écran : pictogramme en dégradé, nom, sous-titre.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.color,
  });

  final HomeEntry entry;
  final VoidCallback onTap;

  /// Fond de la tuile (par défaut : blanc).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color ?? theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.s),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: entry.gradient),
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Icon(entry.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: AppSpace.m),
              // Le nom en entier, réduit s'il le faut.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.label,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille de tuiles, 2 par ligne.
class EntryGrid extends StatelessWidget {
  const EntryGrid({
    super.key,
    required this.entries,
    required this.onOpen,
    this.tileColor,
  });

  final List<HomeEntry> entries;
  final EntryOpener onOpen;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - AppSpace.m) / 2;
      return Wrap(
        spacing: AppSpace.m,
        runSpacing: AppSpace.m,
        children: [
          for (final e in entries)
            SizedBox(
              width: width,
              height: 128,
              child: EntryTile(
                entry: e,
                color: tileColor,
                onTap: () => onOpen(e),
              ),
            ),
        ],
      );
    },
  );
}

/// « jeudi 13 novembre ».
String longDate(DateTime d) {
  const days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}
