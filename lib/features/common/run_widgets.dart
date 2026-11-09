import 'package:flutter/material.dart';

import '../home/home_entry.dart';

/// En-tête en dégradé des écrans de course.
class RunHeader extends StatelessWidget {
  const RunHeader({super.key, required this.entry, this.trailing});

  final HomeEntry entry;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: entry.gradient),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              Icon(entry.icon, color: Colors.white),
              const SizedBox(width: 10),
              // Le titre se tronque si l'information de droite est longue.
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Préparation de la piste en cours.
class RunPreparing extends StatelessWidget {
  const RunPreparing({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(status, textAlign: TextAlign.center),
      ],
    ),
  );
}

/// Message d'erreur centré.
class RunMessage extends StatelessWidget {
  const RunMessage({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

/// Ducking, arrêt, lecture-pause et mode poche.
class RunControls extends StatelessWidget {
  const RunControls({
    super.key,
    required this.playing,
    required this.duckOthers,
    required this.onPlayPause,
    required this.onStop,
    required this.onDuckChanged,
    required this.onPocketMode,
  });

  final bool playing;
  final bool duckOthers;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<bool>? onDuckChanged;
  final VoidCallback onPocketMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Baisser la musique'),
              value: duckOthers,
              onChanged: onDuckChanged,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Recommencer',
                  iconSize: 32,
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                ),
                const SizedBox(width: 24),
                SizedBox.square(
                  dimension: 88,
                  child: IconButton.filled(
                    tooltip: playing ? 'Pause' : 'Lecture',
                    iconSize: 48,
                    onPressed: onPlayPause,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.outlined(
                  tooltip: 'Mode poche',
                  iconSize: 32,
                  onPressed: onPocketMode,
                  icon: const Icon(Icons.phonelink_lock),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « 03:07 » pour 187 s.
String formatClock(double seconds) {
  final total = seconds.floor();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
