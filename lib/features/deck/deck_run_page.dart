import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/deck_program.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/deck.dart';
import '../../domain/workout_plan.dart';
import '../common/duration_text.dart';
import '../common/pocket_mode_overlay.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import '../workouts/workouts_controller.dart';
import 'deck_editor_page.dart';

/// Séance « deck » : la carte du bloc se retourne, défausse et paquet
/// restant visibles ; bande-son pré-générée (lièvre pour les distances).
class DeckRunPage extends ConsumerStatefulWidget {
  const DeckRunPage({super.key, required this.draw, required this.plan});

  final DeckDraw draw;
  final WorkoutPlan plan;

  @override
  ConsumerState<DeckRunPage> createState() => _DeckRunPageState();
}

class _DeckRunPageState extends ConsumerState<DeckRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];

  PreparedTrack? _track;
  String _status = 'Mélange du paquet…';
  String? _error;
  var _duckOthers = true;
  var _playing = false;
  var _position = Duration.zero;
  var _pocketMode = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _wakeLock.enable();
    _subscriptions
      ..add(_player.positionStream.listen((p) => setState(() => _position = p)))
      ..add(_player.playingStream.listen((p) => setState(() => _playing = p)));
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final preferences = await ref.read(preferencesRepositoryProvider.future);
      _duckOthers = await preferences.duckOthers();
      final service = await ref.read(trackServiceProvider.future);
      final track = await service.prepare(
        deckProgram(widget.draw, widget.plan),
        onProgress: (step) {
          if (mounted) setState(() => _status = step);
        },
      );
      await _player.configure(duckOthers: _duckOthers);
      await _player.load(track.path);
      if (mounted) setState(() => _track = track);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible de préparer la séance : $e');
      }
    }
  }

  Future<void> _setDuckOthers(bool value) async {
    setState(() => _duckOthers = value);
    await _player.configure(duckOthers: value);
    final preferences = await ref.read(preferencesRepositoryProvider.future);
    await preferences.setDuckOthers(value);
  }

  Future<void> _save() async {
    final workout = widget.draw.toWorkout(
      id: 'perso-${DateTime.now().microsecondsSinceEpoch}',
      name: '${widget.draw.deck.name} · graine ${widget.draw.seed}',
    );
    await ref.read(workoutsControllerProvider.notifier).save(workout);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Séance ajoutée à « Mes séances »')),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _wakeLock.disable();
    _player.stop().whenComplete(_player.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final elapsedS = track?.activityTimeAt(_position) ?? -1;
    final elapsed = Duration(milliseconds: (elapsedS * 1000).round());
    final done =
        track != null &&
        elapsed >= widget.plan.totalDuration &&
        widget.plan.totalDuration > Duration.zero;

    final page = Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: HomeEntry.deck,
            trailing: 'graine ${widget.draw.seed}',
          ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : done
                ? _Recap(
                    draw: widget.draw,
                    plan: widget.plan,
                    saved: _saved,
                    onSave: _save,
                  )
                : _Table(
                    draw: widget.draw,
                    plan: widget.plan,
                    elapsed: elapsed,
                    started: elapsedS >= 0,
                  ),
          ),
          if (track != null && !done)
            RunControls(
              playing: _playing,
              duckOthers: _duckOthers,
              onPlayPause: _playing ? _player.pause : _player.play,
              onStop: _player.stop,
              onDuckChanged: _playing ? null : _setDuckOthers,
              onPocketMode: () => setState(() => _pocketMode = true),
            ),
        ],
      ),
    );
    if (!_pocketMode || done) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: PocketModeOverlay(
            entry: HomeEntry.deck,
            onExit: () => setState(() => _pocketMode = false),
          ),
        ),
      ],
    );
  }
}

/// Table de jeu : paquet restant, carte du bloc, défausse.
class _Table extends StatelessWidget {
  const _Table({
    required this.draw,
    required this.plan,
    required this.elapsed,
    required this.started,
  });

  final DeckDraw draw;
  final WorkoutPlan plan;
  final Duration elapsed;
  final bool started;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final efforts = plan.efforts.toList();
    final step = started ? plan.stepAt(elapsed) : null;
    final current = step is EffortStep ? step : null;
    // Prochaine carte (face cachée) pendant l'intro ou une récupération.
    final next = efforts.where((e) => e.start >= elapsed).firstOrNull;
    final shown = current ?? next;
    final played = [
      for (final e in efforts)
        if (started && e.end <= elapsed) draw.cards[e.index - 1],
    ];
    final remaining =
        draw.cards.length - played.length - (current == null ? 0 : 1);
    final remainingTime = switch (step) {
      final s? => s.end - elapsed,
      null =>
        started ? null : Duration(milliseconds: (-elapsed.inMilliseconds)),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.layers),
            const SizedBox(width: 6),
            Expanded(child: Text('$remaining dans le paquet')),
            const Icon(Icons.delete_sweep_outlined),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${played.length} jouée(s)',
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (shown != null)
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: _flip,
              child: current != null
                  ? _CardFace(
                      key: ValueKey('face-${current.index}'),
                      card: draw.cards[current.index - 1],
                      index: current.index,
                      total: current.total,
                    )
                  : _CardBack(
                      key: ValueKey('back-${shown.index}'),
                      index: shown.index,
                      total: shown.total,
                    ),
            ),
          ),
        const SizedBox(height: 12),
        if (remainingTime != null)
          Text(
            '${current != null ? 'Effort' : (started ? 'Récupération' : 'Départ')} · '
            '${formatClock(remainingTime.inMilliseconds / 1000 + 0.999)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (played.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Défausse', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in played)
                Chip(
                  avatar: Icon(cardIcon(c.kind), size: 16),
                  label: Text(c.title),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Retournement de carte autour de l'axe vertical.
  static Widget _flip(Widget child, Animation<double> animation) =>
      AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final angle = (1 - animation.value) * pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: child,
          );
        },
      );
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.card,
    required this.index,
    required this.total,
  });

  final EffortCard card;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = switch (card.kind) {
      CardKind.distance => [const Color(0xFF1E63E9), const Color(0xFF0EA5E9)],
      CardKind.time => [const Color(0xFF4338CA), const Color(0xFF1E63E9)],
      CardKind.sprint => [const Color(0xFFDC2626), const Color(0xFFF97316)],
      CardKind.hill => [const Color(0xFF15803D), const Color(0xFF0EA5E9)],
      CardKind.joker => [const Color(0xFF7C3AED), const Color(0xFFDB2777)],
    };
    return _CardFrame(
      gradient: colors,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Carte $index/$total',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Icon(cardIcon(card.kind), color: Colors.white, size: 56),
          const SizedBox(height: 12),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({super.key, required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => _CardFrame(
    gradient: const [Color(0xFF0B2A6F), Color(0xFF1E3A8A)],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'Carte $index/$total',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    ),
  );
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.gradient, required this.child});

  final List<Color> gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    height: 320,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
      ],
    ),
    child: child,
  );
}

class _Recap extends StatelessWidget {
  const _Recap({
    required this.draw,
    required this.plan,
    required this.saved,
    required this.onSave,
  });

  final DeckDraw draw;
  final WorkoutPlan plan;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Partie terminée !',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${draw.cards.length} cartes jouées · ${formatSplit(plan.totalDuration)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final (i, c) in draw.cards.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(c.title),
            trailing: Icon(cardIcon(c.kind)),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saved ? null : onSave,
          icon: Icon(saved ? Icons.check : Icons.bookmark_add),
          label: Text(
            saved ? 'Séance sauvée' : 'Sauver la séance pour la refaire',
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminer'),
        ),
      ],
    );
  }
}
