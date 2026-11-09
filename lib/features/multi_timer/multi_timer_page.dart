import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device/race_clock.dart';
import '../../device/screen_wake_lock.dart';
import '../../device/share_service.dart';
import '../../domain/multi_timer.dart';
import '../common/date_text.dart';
import '../common/duration_text.dart';
import '../common/tap_grid.dart';

/// Chronométrage : départ, un tap par passage, annulation, résultats.
class MultiTimerPage extends ConsumerStatefulWidget {
  const MultiTimerPage({
    super.key,
    required this.names,
    required this.targetLaps,
    required this.lapLengthM,
  });

  final List<String> names;
  final int targetLaps;
  final double lapLengthM;

  @override
  ConsumerState<MultiTimerPage> createState() => _MultiTimerPageState();
}

class _MultiTimerPageState extends ConsumerState<MultiTimerPage> {
  late final RaceClock _clock = ref.read(raceClockFactoryProvider)();
  late final ScreenWakeLock _wakeLock = ref.read(screenWakeLockProvider);
  late final _timer = MultiTimer(widget.names, targetLaps: widget.targetLaps);
  Timer? _ticker;
  var _started = false;
  var _showResults = false;

  @override
  void initState() {
    super.initState();
    _wakeLock.enable();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _wakeLock.disable();
    super.dispose();
  }

  void _start() {
    _clock.start();
    HapticFeedback.heavyImpact();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
    setState(() => _started = true);
  }

  void _tap(int runner) {
    if (_timer.tap(runner, _clock.elapsed)) {
      HapticFeedback.mediumImpact();
      setState(() {});
    }
  }

  void _undo() {
    if (_timer.undo()) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _finish() {
    _ticker?.cancel();
    setState(() => _showResults = true);
  }

  Future<void> _share() => ref
      .read(shareServiceProvider)
      .shareText(
        _timer.exportText(
          title: 'Chrono du ${formatDateTime(DateTime.now())}',
          lapLengthM: widget.lapLengthM,
        ),
        subject: 'Résultats du chrono',
      );

  TapGridItem _item(RunnerTimes r) {
    final finished = r.isFinished(widget.targetLaps);
    final detail = r.laps == 0
        ? 'Tour 1/${widget.targetLaps}'
        : finished
        ? 'Arrivé · ${formatSplit(r.passages.last)}'
        : 'Tour ${r.laps + 1}/${widget.targetLaps} · '
              '${formatSplit(r.lapTimes.last)}';
    return TapGridItem(
      label: r.name,
      detail: detail,
      state: finished ? TapState.done : TapState.ready,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _Results(timer: _timer, onShare: _share);
    }
    final theme = Theme.of(context);
    final last = _timer.lastTap;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chrono'),
        actions: [
          if (_started)
            TextButton(onPressed: _finish, child: const Text('Terminer')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              Text(
                formatSplit(_started ? _clock.elapsed : Duration.zero),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _started
                    ? TapGrid(
                        items: [for (final r in _timer.runners) _item(r)],
                        onTap: _tap,
                      )
                    : Center(
                        child: SizedBox.square(
                          dimension: 220,
                          child: FilledButton(
                            onPressed: _start,
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              textStyle: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            child: const Text('Départ'),
                          ),
                        ),
                      ),
              ),
              if (_started) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: last == null ? null : _undo,
                        icon: const Icon(Icons.undo),
                        label: Text(
                          last == null
                              ? 'Annuler'
                              : 'Annuler : ${_timer.runners[last.runner].name} '
                                    'tour ${last.lap}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    if (_timer.allFinished) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _finish,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          child: const Text('Résultats'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.timer, required this.onShare});

  final MultiTimer timer;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share),
            onPressed: onShare,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in timer.standings())
            Card(
              color: theme.colorScheme.surfaceContainerLowest,
              child: ExpansionTile(
                leading: CircleAvatar(child: Text('${s.rank}')),
                title: Text(
                  s.runner.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    '${s.runner.laps} tour(s)',
                    if (s.runner.laps > 0) formatSplit(s.runner.passages.last),
                    if (s.gap != null && s.rank > 1) '+${formatSplit(s.gap!)}',
                    if (s.runner.bestLap case final best?)
                      'meilleur ${formatSplit(best)}',
                  ].join(' · '),
                ),
                children: [
                  for (final (i, lap) in s.runner.lapTimes.indexed)
                    ListTile(
                      dense: true,
                      title: Text('Tour ${i + 1}'),
                      trailing: Text(
                        '${formatSplit(lap)}   (${formatSplit(s.runner.passages[i])})',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share),
            label: const Text('Partager les résultats'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}
