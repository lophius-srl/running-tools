import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/timed_test.dart';
import '../common/decimal_text.dart';
import '../common/pocket_mode_overlay.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import '../result/result_page.dart';

/// Cooper / demi-Cooper : chrono annoncé, puis saisie de la distance.
class TimedRunPage extends ConsumerStatefulWidget {
  const TimedRunPage({super.key, required this.test});

  final TimedTest test;

  @override
  ConsumerState<TimedRunPage> createState() => _TimedRunPageState();
}

class _TimedRunPageState extends ConsumerState<TimedRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _distance = TextEditingController();

  PreparedTimedTrack? _track;
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
      final track = await service.prepareTimed(
        widget.test,
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

  void _showResult(double distanceM) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultPage.timed(widget.test, distanceM),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _distance.dispose();
    _wakeLock.disable();
    _player.stop().whenComplete(_player.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final testTime = track == null
        ? 0.0
        : _position.inMilliseconds / 1000 - track.leadIn;
    final finished = testTime >= widget.test.duration.inSeconds;

    final page = Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.ofTimedTest(widget.test)),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : finished
                ? _DistanceEntry(controller: _distance, onSubmit: _showResult)
                : _Clock(test: widget.test, testTime: testTime),
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
            onExit: () => setState(() => _pocketMode = false),
          ),
        ),
      ],
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.test, required this.testTime});

  final TimedTest test;
  final double testTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = test.duration.inSeconds;
    final started = testTime >= 0;
    final remaining = started ? total - testTime : total.toDouble();

    return Center(
      child: SizedBox.square(
        dimension: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: started ? testTime / total : 0,
              strokeWidth: 14,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    started
                        ? formatClock(remaining.ceilToDouble())
                        : 'Départ dans ${(-testTime).ceil()} s',
                    style:
                        (started
                                ? theme.textTheme.displayLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                  ),
                  if (started)
                    Text('restantes', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceEntry extends StatefulWidget {
  const _DistanceEntry({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<double> onSubmit;

  @override
  State<_DistanceEntry> createState() => _DistanceEntryState();
}

class _DistanceEntryState extends State<_DistanceEntry> {
  @override
  Widget build(BuildContext context) {
    final distance = parseDecimal(widget.controller.text);
    final valid = distance != null && distance > 0;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Temps écoulé !',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Quelle distance as-tu parcourue ?'),
        const SizedBox(height: 16),
        TextField(
          controller: widget.controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Distance parcourue',
            suffixText: 'm',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: valid ? () => widget.onSubmit(distance) : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Voir le résultat'),
        ),
      ],
    );
  }
}
