import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/home_entry.dart';
import 'hold_to_confirm.dart';

/// Écran sombre pour courir téléphone en poche : seuls des appuis maintenus
/// ont un effet, un tap accidentel ne fait rien. Reprend les couleurs de
/// l'activité en cours.
class PocketModeOverlay extends StatefulWidget {
  const PocketModeOverlay({
    super.key,
    required this.entry,
    this.onDropOut,
    required this.onExit,
  });

  static const dropOutHold = Duration(seconds: 2);
  static const exitHold = Duration(seconds: 1);

  /// Activité en cours (couleurs, icône, nom).
  final HomeEntry entry;

  /// Action « J'ai décroché » ; absente pour les tests chronométrés.
  final VoidCallback? onDropOut;
  final VoidCallback onExit;

  @override
  State<PocketModeOverlay> createState() => _PocketModeOverlayState();
}

class _PocketModeOverlayState extends State<PocketModeOverlay> {
  // Presque noir : peu de lumière en poche, et l'OLED consomme peu.
  static const _top = Color(0xFF050A18);
  static const _bottom = Color(0xFF0B1A3A);
  static const _muted = Color(0xFF8A9BC4);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final accent = entry.gradient.last;
    // Posé par-dessus l'écran, hors du Scaffold : il lui faut son Material
    // pour que les textes aient le style du thème.
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_top, _bottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                _Pill(entry: entry),
                const SizedBox(height: 12),
                Text(
                  'Écran verrouillé · les appuis simples sont ignorés',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
                ),
                const Spacer(),
                if (widget.onDropOut case final onDropOut?)
                  _GlowCircle(
                    entry: entry,
                    size: 240,
                    child: HoldToConfirm(
                      duration: PocketModeOverlay.dropOutHold,
                      onConfirmed: onDropOut,
                      size: 240,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag, color: Colors.white, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            "J'ai décroché",
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'maintiens 2 s',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _GlowCircle(
                    entry: entry,
                    size: 160,
                    child: Icon(
                      entry.icon,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 64,
                    ),
                  ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: HoldToConfirm(
                    duration: PocketModeOverlay.exitHold,
                    onConfirmed: widget.onExit,
                    color: accent,
                    size: 76,
                    child: const Icon(Icons.lock_open, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Maintiens pour déverrouiller',
                  style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille « Mode poche · VAMEVAL », comme sur l'accueil.
class _Pill extends StatelessWidget {
  const _Pill({required this.entry});

  final HomeEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: entry.gradient),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(entry.icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Mode poche · ${entry.label}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Disque aux couleurs de l'activité, atténué pour rester sombre.
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.entry,
    required this.size,
    required this.child,
  });

  final HomeEntry entry;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [for (final c in entry.gradient) c.withValues(alpha: 0.35)],
      ),
      boxShadow: [
        BoxShadow(
          color: entry.gradient.first.withValues(alpha: 0.25),
          blurRadius: 48,
        ),
      ],
    ),
    child: child,
  );
}
