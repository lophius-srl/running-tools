import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../audio/beep_player.dart';
import '../../audio/providers.dart';
import '../../audio/test_programs.dart';
import '../../audio/track_service.dart';
import '../../data/providers.dart';
import '../../device/screen_wake_lock.dart';
import '../../device/share_service.dart';
import '../../domain/beep_schedule.dart';
import '../../domain/club_session.dart';
import '../../domain/staged_test_setup.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/paces_card.dart';
import '../common/run_widgets.dart';
import '../common/tap_grid.dart';
import '../home/home_entry.dart';

/// Test de groupe : une bande-son, un bouton par coureur (« a décroché »).
class ClubRunPage extends ConsumerStatefulWidget {
  const ClubRunPage({super.key, required this.setup, required this.names});

  final StagedTestSetup setup;
  final List<String> names;

  @override
  ConsumerState<ClubRunPage> createState() => _ClubRunPageState();
}

class _ClubRunPageState extends ConsumerState<ClubRunPage> {
  late final BeepPlayer _player = ref.read(beepPlayerFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  late final _schedule = BeepSchedule.generate(
    widget.setup.protocol,
    duration: widget.setup.maxDuration,
  );
  late final _session = ClubSession(
    test: widget.setup.test,
    schedule: _schedule,
    names: widget.names,
  );
  final _subscriptions = <StreamSubscription<Object?>>[];

  PreparedTrack? _track;
  String _status = 'Préparation de la piste…';
  String? _error;
  var _duckOthers = true;
  var _playing = false;
  var _position = Duration.zero;
  var _showResults = false;

  @override
  void initState() {
    super.initState();
    _wakeLock.enable();
    _subscriptions
      ..add(_player.positionStream.listen(_onPosition))
      ..add(_player.playingStream.listen((p) => setState(() => _playing = p)));
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final preferences = await ref.read(preferencesRepositoryProvider.future);
      _duckOthers = await preferences.duckOthers();
      final service = await ref.read(trackServiceProvider.future);
      final track = await service.prepare(
        stagedTestProgram(_schedule, testName: widget.setup.test.label),
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

  double get _testTime => _track?.activityTimeAt(_position) ?? 0;

  void _onPosition(Duration position) {
    setState(() => _position = position);
    // Fin de la piste : ceux qui courent encore ont tout tenu.
    if (!_showResults && _testTime >= _schedule.durationS) _finish();
  }

  void _dropOut(int participant) {
    if (_session.dropOut(participant, _testTime)) {
      HapticFeedback.heavyImpact();
      setState(() {});
      if (_session.allDropped) _finish();
    }
  }

  void _finish() {
    _session.finishAt(_testTime.clamp(0, _schedule.durationS).toDouble());
    _player.pause();
    setState(() => _showResults = true);
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

  TapGridItem _item(int i) {
    final outcome = _session.outcomeOf(i);
    if (outcome == null) {
      return TapGridItem(label: widget.names[i], detail: 'En course');
    }
    final percent = (outcome.fractionOfNextStage * 100).round();
    return TapGridItem(
      label: widget.names[i],
      detail: outcome.hasResult
          ? 'Palier ${outcome.completedStages} + $percent %'
          : 'Aucun palier',
      state: TapState.done,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _ClubResults(session: _session, setup: widget.setup);
    }
    final theme = Theme.of(context);
    final track = _track;
    final testTime = _testTime;
    final stage = _schedule.positionAt(testTime);
    final last = _session.lastDropOut;
    final started = testTime > 0;

    return Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: HomeEntry.club,
            trailing: started
                ? 'Palier ${stage.stage} · ${formatKmh(stage.speedKmh)} km/h'
                : widget.setup.test.label,
          ),
          if (track != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                started
                    ? formatClock(testTime)
                    : 'Départ dans ${(-testTime).ceil()} s',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.error_outline, text: _error!)
                : track == null
                ? RunPreparing(status: _status)
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: TapGrid(
                      items: [
                        for (var i = 0; i < widget.names.length; i++) _item(i),
                      ],
                      onTap: _dropOut,
                    ),
                  ),
          ),
          if (track != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: last == null
                            ? null
                            : () {
                                _session.undo();
                                setState(() {});
                              },
                        icon: const Icon(Icons.undo),
                        label: Text(
                          last == null
                              ? 'Annuler'
                              : 'Annuler : ${widget.names[last]}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 56,
                      child: IconButton.filled(
                        tooltip: _playing ? 'Pause' : 'Lecture',
                        onPressed: _playing ? _player.pause : _player.play,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 56,
                      child: IconButton.filledTonal(
                        tooltip: 'Terminer',
                        onPressed: started ? _finish : null,
                        icon: const Icon(Icons.sports_score),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClubResults extends ConsumerStatefulWidget {
  const _ClubResults({required this.session, required this.setup});

  final ClubSession session;
  final StagedTestSetup setup;

  @override
  ConsumerState<_ClubResults> createState() => _ClubResultsState();
}

class _ClubResultsState extends ConsumerState<_ClubResults> {
  var _prorata = false;

  Future<void> _share() => ref
      .read(shareServiceProvider)
      .shareText(
        widget.session.exportText(
          prorata: _prorata,
          title:
              '${widget.setup.test.label} de groupe, '
              '${formatDateTime(DateTime.now())}',
        ),
        subject: 'Résultats du test de groupe',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = widget.session.results(prorata: _prorata);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats du groupe'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share),
            onPressed: _share,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prorata du palier entamé'),
            value: _prorata,
            onChanged: (v) => setState(() => _prorata = v),
          ),
          for (final (i, r) in results.indexed)
            Card(
              color: theme.colorScheme.surfaceContainerLowest,
              child: switch (r.outcome.result(prorata: _prorata)) {
                null => ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(r.name),
                  subtitle: const Text('Aucun palier complet'),
                ),
                final result => ExpansionTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(
                    '${r.name} · VMA ${formatKmh(result.vmaKmh)} km/h',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Palier ${r.outcome.completedStages} · '
                    'VO2max ${formatDecimal((result.vo2max * 10).round() / 10)}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [PacesCard(vmaKmh: result.vmaKmh)],
                ),
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
            label: const Text('Partager les résultats'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }
}
