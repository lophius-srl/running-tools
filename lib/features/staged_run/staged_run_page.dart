import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../audio/beep_player.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/stage_protocol.dart';
import '../../domain/staged_outcome.dart';
import '../../domain/staged_test_setup.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import '../result/result_page.dart';
import '../common/pocket_mode_overlay.dart';

/// Écran de course d'un test par paliers : prépare puis joue la piste.
class StagedRunPage extends ConsumerStatefulWidget {
  const StagedRunPage({super.key, required this.setup});

  final StagedTestSetup setup;

  @override
  ConsumerState<StagedRunPage> createState() => _StagedRunPageState();
}

class _StagedRunPageState extends ConsumerState<StagedRunPage> {
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
    // Écran allumé pendant tout le test, relâché en quittant l'écran.
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
        widget.setup,
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

  /// Arrête la piste et calcule le palier atteint depuis la position.
  Future<void> _dropOut(PreparedTrack track) async {
    final testTime = track.renderer.testTimeAt(_player.position);
    await _player.pause();
    final outcome = StagedOutcome.at(
      widget.setup.test,
      track.schedule,
      testTime,
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultPage.staged(outcome)),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _wakeLock.disable();
    // stop() rend la main à la musique avant de libérer le lecteur.
    _player.stop().whenComplete(_player.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final page = Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: HomeEntry.ofStagedTest(widget.setup.test),
            trailing: '${formatKmh(widget.setup.protocol.markerSpacingM)} m',
          ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : _Running(
                    test: widget.setup.test,
                    track: track,
                    position: _position,
                    voiceError: track.voiceError,
                  ),
          ),
          if (track != null && _position > Duration.zero)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: () => _dropOut(track),
                icon: const Icon(Icons.flag, size: 32),
                label: const Text("J'ai décroché"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(96),
                  textStyle: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          if (track != null)
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
    if (!_pocketMode || track == null) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: PocketModeOverlay(
            onDropOut: () => _dropOut(track),
            onExit: () => setState(() => _pocketMode = false),
          ),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.test,
    required this.track,
    required this.position,
    required this.voiceError,
  });

  final StagedTest test;
  final PreparedTrack track;
  final Duration position;
  final String? voiceError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final testTime = track.renderer.testTimeAt(position);
    final finished = testTime >= track.schedule.durationS;
    final stage = track.schedule.positionAt(testTime);
    final protocol = track.schedule.protocol;
    final nextStageInS = testTime < 0
        ? protocol.stageSeconds - testTime
        : (1 - stage.fractionOfStage) * protocol.stageSeconds;

    final String clock;
    if (testTime < 0) {
      clock = 'Départ dans ${(-testTime).ceil()} s';
    } else if (finished) {
      clock = 'Fin de la piste';
    } else {
      clock = formatClock(testTime);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          clock,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: HomeEntry.ofStagedTest(test).gradient,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Text(
                'Palier ${stage.stage}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${formatKmh(stage.speedKmh)} km/h',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: testTime < 0 ? 0 : stage.fractionOfStage,
                  minHeight: 12,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Tile(
              icon: Icons.route,
              value: '${testTime < 0 ? 0 : stage.distanceM.round()} m',
              label: 'parcourus',
            ),
            const SizedBox(width: 12),
            _Tile(
              icon: Icons.trending_up,
              value:
                  '${formatKmh(stage.speedKmh + protocol.incrementKmh)} km/h',
              label: finished
                  ? 'palier suivant'
                  : 'dans ${nextStageInS.ceil()} s',
            ),
          ],
        ),
        if (voiceError != null) ...[
          const SizedBox(height: 16),
          Text(
            'Annonces vocales indisponibles : bips seuls.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
