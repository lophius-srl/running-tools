import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/cadence_coach.dart';
import '../../audio/metronome_program.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/accelerometer.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/cadence.dart';
import '../../domain/cadence_advice.dart';
import '../common/pocket_mode_overlay.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';

/// Métronome de cadence, avec mesure optionnelle de la cadence réelle.
class MetronomePage extends ConsumerStatefulWidget {
  const MetronomePage({super.key});

  static const minCadence = 140;
  static const maxCadence = 200;
  static const durations = [10, 20, 30, 45, 60];

  /// Délai minimal entre deux conseils vocaux.
  static const adviceInterval = Duration(seconds: 45);

  @override
  ConsumerState<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends ConsumerState<MetronomePage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final CadenceCoach _coach;
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _detector = CadenceDetector();
  StreamSubscription<AccelSample>? _accel;

  var _cadence = 175;
  var _minutes = 20;
  var _measure = false;
  var _duckOthers = true;
  var _playing = false;
  var _pocketMode = false;
  var _position = Duration.zero;
  PreparedTrack? _track;
  String? _preparing;
  double? _measured;
  Duration? _lastAdvice;

  @override
  void initState() {
    super.initState();
    // Créé ici : dispose() ne peut plus utiliser ref.
    _coach = ref.read(cadenceCoachFactoryProvider)();
    _wakeLock.enable();
    _subscriptions
      ..add(_player.positionStream.listen(_onPosition))
      ..add(_player.playingStream.listen((p) => setState(() => _playing = p)));
    _loadDuck();
  }

  Future<void> _loadDuck() async {
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    final duck = await prefs.duckOthers();
    if (mounted) setState(() => _duckOthers = duck);
  }

  void _onPosition(Duration position) {
    setState(() => _position = position);
    _maybeAdvise(position);
  }

  /// Conseil vocal si l'écart dépasse la tolérance, au plus toutes les 45 s.
  void _maybeAdvise(Duration position) {
    if (!_measure || !_playing) return;
    final last = _lastAdvice;
    if (last != null && position - last < MetronomePage.adviceInterval) return;
    final advice = adviceFor(_measured, _cadence);
    if (advice == null) return;
    _lastAdvice = position;
    _coach.say(advice);
  }

  Future<void> _start() async {
    setState(() => _preparing = 'Préparation…');
    final service = await ref.read(trackServiceProvider.future);
    final track = await service.prepare(
      metronomeProgram(
        stepsPerMinute: _cadence,
        duration: Duration(minutes: _minutes),
      ),
      onProgress: (step) {
        if (mounted) setState(() => _preparing = step);
      },
    );
    if (_measure) await _coach.prepare();
    await _player.configure(duckOthers: _duckOthers);
    await _player.load(track.path);
    if (!mounted) return;
    setState(() {
      _track = track;
      _preparing = null;
      _lastAdvice = null;
    });
    if (_measure) _startMeasuring();
    await _player.play();
  }

  void _startMeasuring() {
    _detector.reset();
    _accel?.cancel();
    _accel = ref.read(accelerometerProvider).samples().listen((s) {
      _detector.add(s.time, s.x, s.y, s.z);
      final cadence = _detector.cadence;
      if (cadence != _measured && mounted) setState(() => _measured = cadence);
    });
  }

  Future<void> _stop() async {
    await _player.stop();
    await _accel?.cancel();
    _accel = null;
    if (mounted) {
      setState(() {
        _track = null;
        _measured = null;
      });
    }
  }

  Future<void> _setDuck(bool value) async {
    setState(() => _duckOthers = value);
    await _player.configure(duckOthers: value);
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    await prefs.setDuckOthers(value);
  }

  void _changeCadence(int delta) => setState(
    () => _cadence = (_cadence + delta).clamp(
      MetronomePage.minCadence,
      MetronomePage.maxCadence,
    ),
  );

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _accel?.cancel();
    _wakeLock.disable();
    _coach.dispose();
    _player.stop().whenComplete(_player.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _track != null;
    final locked = running || _preparing != null;
    final remaining = running
        ? Duration(minutes: _minutes) -
              Duration(
                microseconds: (_track!.activityTimeAt(_position) * 1e6).round(),
              )
        : Duration(minutes: _minutes);

    final page = Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.metronome),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '$_cadence',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Text('pas/min', textAlign: TextAlign.center),
                if (!running) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final d in [-5, -1, 1, 5])
                        Expanded(
                          child: _StepButton(
                            label: d > 0 ? '+$d' : '$d',
                            onPressed: locked ? null : () => _changeCadence(d),
                          ),
                        ),
                    ],
                  ),
                  Slider(
                    value: _cadence.toDouble(),
                    min: MetronomePage.minCadence.toDouble(),
                    max: MetronomePage.maxCadence.toDouble(),
                    divisions:
                        MetronomePage.maxCadence - MetronomePage.minCadence,
                    label: '$_cadence',
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _cadence = v.round()),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in MetronomePage.durations)
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: _minutes == m,
                          onSelected: locked
                              ? null
                              : (_) => setState(() => _minutes = m),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Mesurer ma cadence'),
                    subtitle: const Text(
                      'Accéléromètre ; conseil vocal si l’écart dépasse 3 pas/min',
                    ),
                    value: _measure,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _measure = v),
                  ),
                ],
                if (running) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${formatClock(remaining.inMilliseconds / 1000)} restantes',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (_measure)
                    _MeasuredCard(measured: _measured, target: _cadence),
                ],
                if (_preparing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: RunPreparing(status: _preparing!),
                  ),
              ],
            ),
          ),
          if (!running)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _preparing == null ? _start : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Démarrer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                  ),
                ),
              ),
            )
          else
            RunControls(
              playing: _playing,
              duckOthers: _duckOthers,
              onPlayPause: _playing ? _player.pause : _player.play,
              onStop: _stop,
              onDuckChanged: _playing ? null : _setDuck,
              onPocketMode: () => setState(() => _pocketMode = true),
            ),
        ],
      ),
    );
    if (!_pocketMode || !running) return page;
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: SizedBox(
      height: 56,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

/// Cadence mesurée et écart avec la cible.
class _MeasuredCard extends StatelessWidget {
  const _MeasuredCard({required this.measured, required this.target});

  final double? measured;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final measured = this.measured;
    final deviation = cadenceDeviation(measured, target);
    final advice = adviceFor(measured, target);
    final color = advice == null ? scheme.primary : scheme.error;
    return Card(
      color: scheme.surfaceContainerLowest,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Ma cadence', style: theme.textTheme.titleMedium),
            Text(
              measured == null ? '…' : '${measured.round()}',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(switch ((deviation, advice)) {
              (null, _) => 'Cours quelques secondes…',
              (final d?, null) => 'Dans la cible (${_signed(d)})',
              (final d?, final a?) => '${a.phrase} (${_signed(d)})',
            }, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  static String _signed(double d) =>
      '${d >= 0 ? '+' : '−'}${d.abs().round()} pas/min';
}
