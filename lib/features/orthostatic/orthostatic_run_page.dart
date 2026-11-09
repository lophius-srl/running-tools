import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/beep_player.dart';
import '../../audio/orthostatic_program.dart';
import '../../audio/providers.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../domain/orthostatic.dart';
import '../common/run_widgets.dart';
import 'orthostatic_page.dart';

/// Test guidé à la voix ; comptage manuel des pulsations (15 s × 4).
class OrthostaticRunPage extends ConsumerStatefulWidget {
  const OrthostaticRunPage({super.key});

  static const protocol = OrthostaticProtocol();

  @override
  ConsumerState<OrthostaticRunPage> createState() => _OrthostaticRunPageState();
}

class _OrthostaticRunPageState extends ConsumerState<OrthostaticRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _counts = [for (var i = 0; i < 3; i++) TextEditingController()];

  PreparedTrack? _track;
  String? _error;
  var _playing = false;
  var _position = Duration.zero;
  OrthostaticResult? _result;
  FormStatus? _status;

  OrthostaticProtocol get _protocol => OrthostaticRunPage.protocol;

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
      final service = await ref.read(trackServiceProvider.future);
      final track = await service.prepare(
        orthostaticProgram(_protocol, manual: true),
      );
      // Les consignes passent par-dessus une éventuelle musique, baissée.
      await _player.configure(duckOthers: true);
      await _player.load(track.path);
      if (mounted) setState(() => _track = track);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible de préparer le test : $e');
      }
    }
  }

  Future<void> _save() async {
    final values = [for (final c in _counts) int.tryParse(c.text.trim())];
    if (values.any((v) => v == null || v <= 0)) return;
    final result = OrthostaticResult.fromCounts(
      lying15s: values[0]!,
      standingPeak15s: values[1]!,
      standingStable15s: values[2]!,
      date: DateTime.now(),
    );
    final repo = await ref.read(orthostaticRepositoryProvider.future);
    final previous = await repo.all();
    await repo.add(result);
    if (mounted) {
      setState(() {
        _result = result;
        _status = OrthostaticBaseline.of(previous).statusOf(result);
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final c in _counts) {
      c.dispose();
    }
    _wakeLock.disable();
    _player.stop().whenComplete(_player.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = _track;
    final t = track?.activityTimeAt(_position) ?? -1;
    final elapsed = Duration(milliseconds: (t * 1000).round());
    final finished = track != null && elapsed >= _protocol.total;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Test orthostatique')),
      body: _error != null
          ? RunMessage(icon: Icons.error_outline, text: _error!)
          : track == null
          ? const RunPreparing(status: 'Préparation des consignes…')
          : result != null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResultCard(result: result, status: _status!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Terminer'),
                ),
              ],
            )
          : finished
          ? _CountsForm(counts: _counts, onSave: _save)
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  _instruction(elapsed, started: t >= 0),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  formatClock(
                    ((t >= 0 ? _protocol.total - elapsed : _protocol.total)
                            .inMilliseconds /
                        1000),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Lance le test, pose le téléphone à côté de toi et laisse-toi '
                  'guider par la voix. Pour compter, pose deux doigts sur ton '
                  'poignet ou ton cou.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox.square(
                  dimension: 96,
                  child: IconButton.filled(
                    tooltip: _playing ? 'Pause' : 'Lancer',
                    iconSize: 48,
                    onPressed: _playing ? _player.pause : _player.play,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
              ],
            ),
    );
  }

  String _instruction(Duration elapsed, {required bool started}) {
    if (!started) return 'Allonge-toi sur le dos';
    if (elapsed < _protocol.standUpAt) {
      return manualCountStarts(_protocol).first <= elapsed
          ? 'Compte tes pulsations'
          : 'Allongé, détends-toi';
    }
    return 'Debout, immobile';
  }
}

class _CountsForm extends StatefulWidget {
  const _CountsForm({required this.counts, required this.onSave});

  final List<TextEditingController> counts;
  final VoidCallback onSave;

  @override
  State<_CountsForm> createState() => _CountsFormState();
}

class _CountsFormState extends State<_CountsForm> {
  static const _labels = [
    'Couché (avant de te lever)',
    'Debout, juste après le lever',
    'Debout, à la fin',
  ];

  @override
  Widget build(BuildContext context) {
    final valid = widget.counts.every((c) {
      final v = int.tryParse(c.text.trim());
      return v != null && v > 0;
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Saisis les pulsations comptées pendant chaque top de 15 s :',
        ),
        for (final (i, c) in widget.counts.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                labelText: _labels[i],
                suffixText: 'en 15 s',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valid ? widget.onSave : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Voir le résultat'),
        ),
      ],
    );
  }
}
