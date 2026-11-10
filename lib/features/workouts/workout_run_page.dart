import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../audio/workout_program.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/training_paces.dart';
import '../../domain/workout_plan.dart';
import '../common/duration_text.dart';
import '../common/pocket_mode_overlay.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';

/// Séance en mode chrono : signaux et annonces, étape en cours à l'écran.
class WorkoutRunPage extends ConsumerStatefulWidget {
  const WorkoutRunPage({
    super.key,
    required this.plan,
    this.mode = WorkoutAudioMode.chrono,
  });

  final WorkoutPlan plan;
  final WorkoutAudioMode mode;

  @override
  ConsumerState<WorkoutRunPage> createState() => _WorkoutRunPageState();
}

class _WorkoutRunPageState extends ConsumerState<WorkoutRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];

  PreparedTrack? _track;
  String _status = 'Préparation de la piste…';
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
        workoutProgram(widget.plan, mode: widget.mode),
        onProgress: (step) {
          if (mounted) setState(() => _status = step);
        },
      );
      await _player.configure(duckOthers: _duckOthers);
      await _player.load(track.path);
      if (mounted) setState(() => _track = track);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible de préparer la piste : $e');
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
    final elapsedS = track == null ? -1.0 : track.activityTimeAt(_position);
    final finished =
        track != null &&
        elapsedS * 1e6 >= widget.plan.totalDuration.inMicroseconds;

    final page = Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: HomeEntry.workouts,
            trailing: widget.plan.workout.name,
          ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : finished
                ? _Recap(plan: widget.plan)
                : _Current(
                    plan: widget.plan,
                    elapsedS: elapsedS,
                    showMarkers: widget.mode == WorkoutAudioMode.pacer,
                  ),
          ),
          if (track != null && !finished)
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
    if (!_pocketMode || finished) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: PocketModeOverlay(
            entry: HomeEntry.workouts,
            onExit: () => setState(() => _pocketMode = false),
          ),
        ),
      ],
    );
  }
}

/// Étape en cours, temps restant et étape suivante.
class _Current extends StatelessWidget {
  const _Current({
    required this.plan,
    required this.elapsedS,
    required this.showMarkers,
  });

  final WorkoutPlan plan;
  final double elapsedS;

  /// Lièvre : compteur des repères de la répétition en cours.
  final bool showMarkers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elapsed = Duration(microseconds: (elapsedS * 1e6).round());
    final step = elapsedS < 0 ? null : plan.stepAt(elapsed);
    final next = plan.steps
        .whereType<EffortStep>()
        .where((e) => e.start > elapsed)
        .firstOrNull;
    final remaining = step == null
        ? Duration(microseconds: (-elapsedS * 1e6).round())
        : step.end - elapsed;

    final (title, subtitle, color) = switch (step) {
      null => ('Départ', next == null ? '' : _label(next), scheme.primary),
      final EffortStep e => (
        'Répétition ${e.index}/${e.total}',
        _label(e),
        scheme.primary,
      ),
      RecoveryStep() => (
        'Récupération',
        next == null ? '' : 'Ensuite : ${_label(next)}',
        scheme.tertiary,
      ),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatClock(remaining.inMilliseconds / 1000 + 0.999),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (showMarkers &&
                  step is EffortStep &&
                  step.markerSplits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Repère ${_markersPassed(step, elapsed)}/'
                    '${step.markerSplits.length}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (step != null && step.duration > Duration.zero) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        (elapsed - step.start).inMilliseconds /
                        step.duration.inMilliseconds,
                    minHeight: 10,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Répétitions',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in plan.efforts)
              _RepDot(
                index: e.index,
                done: elapsed >= e.end,
                current: elapsed >= e.start && elapsed < e.end,
              ),
          ],
        ),
      ],
    );
  }
}

/// Pastille d'une répétition : faite, en cours ou à venir.
class _RepDot extends StatelessWidget {
  const _RepDot({
    required this.index,
    required this.done,
    required this.current,
  });

  final int index;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = done || current;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? scheme.primary : scheme.surfaceContainerLowest,
        border: current ? Border.all(color: scheme.tertiary, width: 3) : null,
      ),
      child: done
          ? Icon(Icons.check, color: scheme.onPrimary, size: 20)
          : Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: filled ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
    );
  }
}

/// Fin de séance : rappel des répétitions et de leurs cibles.
class _Recap extends StatelessWidget {
  const _Recap({required this.plan});

  final WorkoutPlan plan;

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
        Text('Durée : ${formatSplit(plan.totalDuration)}'),
        const SizedBox(height: 12),
        for (final e in plan.efforts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${e.index}')),
            title: Text(_label(e)),
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

/// Repères déjà franchis dans la répétition [step] à [elapsed].
int _markersPassed(EffortStep step, Duration elapsed) =>
    step.markerSplits.where((split) => step.start + split <= elapsed).length;

/// « 400 m · 1:36,0 (4:00 /km) » ou « 30 s · ≈ 125 m ».
String _label(EffortStep e) {
  final amount = e.effort.isDistance
      ? '${e.effort.distanceM!.round()} m'
      : formatSplit(e.effort.duration!);
  final speed = e.speedKmh;
  if (speed == null) return '$amount · au ressenti';
  final pace = '${formatPace(paceForSpeed(speed))} /km';
  return e.effort.isDistance
      ? '$amount · ${formatSplit(e.duration)} ($pace)'
      : '$amount · ≈ ${e.distanceM!.round()} m ($pace)';
}
