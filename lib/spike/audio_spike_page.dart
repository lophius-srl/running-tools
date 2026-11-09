import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/announcements.dart';
import '../audio/beep_player.dart';
import '../audio/track_builder.dart';
import '../audio/track_renderer.dart';
import '../domain/beep_schedule.dart';
import '../domain/stage_protocol.dart';

/// Spike : génère et joue une piste VAMEVAL de 15 min (repères à 20 m) pour
/// valider l'audio iOS (écran verrouillé, mode silencieux, musique, appel).
class AudioSpikePage extends StatefulWidget {
  const AudioSpikePage({super.key});

  @override
  State<AudioSpikePage> createState() => _AudioSpikePageState();
}

class _AudioSpikePageState extends State<AudioSpikePage>
    with WidgetsBindingObserver {
  final _schedule = BeepSchedule.generate(
    const StageProtocol.vameval(markerSpacingM: 20),
    duration: const Duration(minutes: 15),
  );
  final _renderer = TrackRenderer();
  final BeepPlayer _player = JustAudioBeepPlayer();
  final _log = <String>[];
  final _subscriptions = <StreamSubscription<Object?>>[];

  var _duckOthers = true;
  var _playing = false;
  var _generating = false;
  String? _status;
  BuiltTrack? _track;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptions
      ..add(_player.positionStream.listen((p) => setState(() => _position = p)))
      ..add(
        _player.playingStream.listen((playing) {
          setState(() => _playing = playing);
          _addLog(playing ? 'Lecture' : 'Pause');
        }),
      );
    _listenToSession();
  }

  Future<void> _listenToSession() async {
    final session = await AudioSession.instance;
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        _addLog(
          'Interruption ${event.begin ? 'début' : 'fin'} (${event.type.name})',
        );
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _addLog('App : ${state.name}');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    if (!mounted) return;
    final now = TimeOfDay.now().format(context);
    final at = _formatClock(_renderer.testTimeAt(_player.position));
    setState(() => _log.insert(0, '$now  [test $at]  $message'));
  }

  Future<void> _generate() async {
    final watch = Stopwatch()..start();
    setState(() {
      _generating = true;
      _status = 'Préparation…';
    });
    try {
      if (_track != null) await _player.stop();
      await _buildAndLoad(watch);
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _buildAndLoad(Stopwatch watch) async {
    final track = await buildTrack(
      schedule: _schedule,
      renderer: _renderer,
      testName: 'Test VAMEVAL',
      workDir: await getTemporaryDirectory(),
      onProgress: (step) => setState(() => _status = step),
    );
    await _player.configure(duckOthers: _duckOthers);
    await _player.load(track.path);
    final mb = (track.bytes / 1e6).toStringAsFixed(1);
    final seconds = (watch.elapsedMilliseconds / 1000).toStringAsFixed(1);
    setState(() {
      _track = track;
      _status = 'Piste prête : $mb Mo, générée en $seconds s';
    });
    if (track.voiceError != null) _addLog('Voix KO : ${track.voiceError}');
  }

  Future<void> _setDuck(bool value) async {
    setState(() => _duckOthers = value);
    await _player.configure(duckOthers: value);
    _addLog(value ? 'Mode : ducking' : 'Mode : mix sans ducking');
  }

  Future<void> _seekBy(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) {
    final testTime = _renderer.testTimeAt(_position);
    final stage = _schedule.positionAt(testTime);
    final ready = _track != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Spike audio · VAMEVAL 20 m')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Baisser la musique (duckOthers)'),
            subtitle: const Text(
              'Sinon les bips se mixent par-dessus à plein volume',
            ),
            value: _duckOthers,
            onChanged: _playing ? null : _setDuck,
          ),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: const Icon(Icons.graphic_eq),
            label: Text(ready ? 'Régénérer la piste' : 'Générer la piste'),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_status!, textAlign: TextAlign.center),
            ),
          const SizedBox(height: 16),
          Text(
            testTime < 0
                ? 'Départ dans ${(-testTime).ceil()} s'
                : _formatClock(testTime),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium,
          ),
          Text(
            'Palier ${stage.stage} · ${formatKmh(stage.speedKmh)} km/h',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(value: stage.fractionOfStage),
          ),
          Text(
            '${stage.distanceM.toStringAsFixed(0)} m',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: ready ? () => _seekBy(-60) : null,
                icon: const Icon(Icons.replay),
                tooltip: '−1 min',
              ),
              IconButton.filled(
                iconSize: 48,
                onPressed: ready
                    ? (_playing ? _player.pause : _player.play)
                    : null,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                onPressed: ready ? _player.stop : null,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop',
              ),
              IconButton(
                onPressed: ready ? () => _seekBy(60) : null,
                icon: const Icon(Icons.forward),
                tooltip: '+1 min',
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Journal', style: theme.textTheme.titleMedium),
          for (final line in _log) Text(line, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _formatClock(double seconds) {
  final sign = seconds < 0 ? '-' : '';
  final total = seconds.abs().floor();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$sign$m:$s';
}
