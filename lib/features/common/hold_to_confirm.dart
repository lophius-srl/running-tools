import 'package:flutter/material.dart';

/// Déclenche [onConfirmed] seulement si l'appui est maintenu [duration].
/// Un anneau montre la progression ; relâcher avant la fin annule.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.duration,
    required this.onConfirmed,
    required this.child,
    this.color = Colors.white,
    this.size = 200,
  });

  final Duration duration;
  final VoidCallback onConfirmed;
  final Widget child;
  final Color color;
  final double size;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _progress.value = 0;
      widget.onConfirmed();
    }
  }

  void _release() {
    if (_progress.isAnimating) {
      _progress.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Appui brut : démarre tout de suite, sans arbitrage avec d'autres gestes.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _progress.forward(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _progress,
              builder: (_, _) => CircularProgressIndicator(
                value: _progress.value,
                strokeWidth: 6,
                color: widget.color,
                backgroundColor: widget.color.withValues(alpha: 0.15),
              ),
            ),
            // Le contenu rétrécit si besoin pour rester dans l'anneau.
            Padding(
              padding: EdgeInsets.all(widget.size * 0.15),
              child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
