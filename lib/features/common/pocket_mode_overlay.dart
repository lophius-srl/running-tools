import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hold_to_confirm.dart';

/// Écran noir pour courir téléphone en poche : seuls des appuis maintenus
/// ont un effet, un tap accidentel ne fait rien.
class PocketModeOverlay extends StatefulWidget {
  const PocketModeOverlay({super.key, this.onDropOut, required this.onExit});

  static const dropOutHold = Duration(seconds: 2);
  static const exitHold = Duration(seconds: 1);

  /// Action « J'ai décroché » ; absente pour les tests chronométrés.
  final VoidCallback? onDropOut;
  final VoidCallback onExit;

  @override
  State<PocketModeOverlay> createState() => _PocketModeOverlayState();
}

class _PocketModeOverlayState extends State<PocketModeOverlay> {
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
    const dim = Color(0xFF3A3A3A);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            HoldToConfirm(
              duration: PocketModeOverlay.exitHold,
              onConfirmed: widget.onExit,
              color: dim,
              size: 72,
              child: const Icon(Icons.lock_open, color: dim),
            ),
            const Text(
              'Maintenir pour quitter le mode poche',
              style: TextStyle(color: dim),
            ),
            const Spacer(),
            if (widget.onDropOut case final onDropOut?)
              HoldToConfirm(
                duration: PocketModeOverlay.dropOutHold,
                onConfirmed: onDropOut,
                color: Colors.deepOrange,
                size: 220,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.deepOrange, size: 48),
                    SizedBox(height: 8),
                    Text(
                      "J'ai décroché",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('maintenir 2 s', style: TextStyle(color: dim)),
                  ],
                ),
              )
            else
              const Icon(Icons.directions_run, color: dim, size: 64),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
