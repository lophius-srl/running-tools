import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/fartlek_program.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/fartlek.dart';
import '../common/duration_text.dart';
import '../common/pocket_mode_overlay.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';

/// Fartlek en cours : phase actuelle seulement (la suite reste une surprise).
class FartlekRunPage extends ConsumerStatefulWidget {
  const FartlekRunPage({super.key, required this.plan, this.vmaKmh});

  final FartlekPlan plan;
  final double? vmaKmh;

  @override
  ConsumerState<FartlekRunPage> createState() => _FartlekRunPageState();
}

class _FartlekRunPageState extends ConsumerState<FartlekRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];

  PreparedTrack? _track;
  String _status = 'Préparation de la séance…';
  String? _error;
  var _duckOthers = true;
  var _playing = false;
  var _position = Duration.zero;
  var _pocketMode = false;

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
        fartlekProgram(widget.plan, vmaKmh: widget.vmaKmh),
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
        track != null && widget.plan.phaseAt(elapsed) == FartlekPhase.done;

    final page = Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: HomeEntry.fartlek,
            trailing: 'graine ${widget.plan.seed}',
          ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : done
                ? _Recap(plan: widget.plan)
                : _Phase(
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
            entry: HomeEntry.fartlek,
            onExit: () => setState(() => _pocketMode = false),
          ),
        ),
      ],
    );
  }
}

class _Phase extends StatelessWidget {
  const _Phase({
    required this.plan,
    required this.elapsed,
    required this.started,
  });

  final FartlekPlan plan;
  final Duration elapsed;
  final bool started;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = plan.settings;
    final phase = started ? plan.phaseAt(elapsed) : FartlekPhase.warmup;
    final burst = plan.burstAt(elapsed);
    final (title, remaining, color) = switch (phase) {
      FartlekPhase.warmup => (
        'Échauffement',
        started ? s.warmup - elapsed : s.warmup,
        scheme.primary,
      ),
      FartlekPhase.burst => (
        'Accélère !',
        burst!.end - elapsed,
        const Color(0xFFDC2626),
      ),
      FartlekPhase.cooldown => (
        'Retour au calme',
        plan.total - elapsed,
        scheme.primary,
      ),
      _ => ('Footing', null, scheme.tertiary),
    };
    final totalLeft = plan.total - (started ? elapsed : Duration.zero);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (remaining != null)
                Text(
                  formatClock(remaining.inMilliseconds / 1000 + 0.999),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Text(
                  'La prochaine accélération peut tomber à tout moment…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Séance : ${formatClock(totalLeft.inMilliseconds / 1000)} restantes',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: started
                ? elapsed.inMilliseconds / plan.total.inMilliseconds
                : 0,
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.plan});

  final FartlekPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Séance terminée !',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${plan.bursts.length} accélérations',
          style: theme.textTheme.titleLarge,
        ),
        Text(
          '${formatSplit(plan.hardTime)} à haute intensité',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final (i, b) in plan.bursts.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(spokenDuration(b.duration)),
            subtitle: Text('à ${formatClock(b.start.inSeconds.toDouble())}'),
          ),
        const SizedBox(height: 12),
        Text(
          'Graine ${plan.seed} : retrouve-la dans « Rejouer une séance '
          'récente » pour refaire la même séance.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Terminer'),
        ),
      ],
    );
  }
}
