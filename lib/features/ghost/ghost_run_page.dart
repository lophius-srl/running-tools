import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/live_voice.dart';
import '../../data/ghost_repository.dart';
import '../../data/providers.dart';
import '../../device/location_source.dart';
import '../../device/race_clock.dart';
import '../../domain/ghost.dart';
import '../../domain/ghost_announcer.dart';
import '../../domain/gps_tracker.dart';
import '../common/run_widgets.dart';
import '../gps/gps_check_page.dart';
import '../home/home_entry.dart';
import 'ghost_page.dart';
import 'ghost_result_page.dart';

/// Course en direct contre le fantôme.
class GhostRunPage extends ConsumerStatefulWidget {
  const GhostRunPage({
    super.key,
    required this.ghost,
    required this.alignment,
    required this.every,
    this.rival,
  });

  final Ghost ghost;
  final GhostAlignment alignment;
  final GhostAnnounceEvery every;

  /// Prénom de l'ami en duo ; `null` contre le fantôme.
  final String? rival;

  @override
  ConsumerState<GhostRunPage> createState() => _GhostRunPageState();
}

class _GhostRunPageState extends ConsumerState<GhostRunPage> {
  late final LiveVoice _voice = ref.read(liveVoiceFactoryProvider)();
  late final _announcer = GhostAnnouncer(
    every: widget.every,
    rival: widget.rival,
  );
  late final RouteMatcher? _matcher = widget.alignment == GhostAlignment.route
      ? RouteMatcher(widget.ghost)
      : null;
  late final RaceClock _clock = ref.read(raceClockFactoryProvider)();
  final _tracker = GpsTracker();
  final _curve = GapCurve();
  StreamSubscription<GpsFix>? _subscription;
  Timer? _ticker;

  DateTime? _startedAt;

  /// Distance déjà comptée avant le départ (échauffement, attente).
  var _startDistanceM = 0.0;
  var _elapsedS = 0.0;
  var _distanceM = 0.0;
  var _offRoute = false;
  GhostGap? _gap;
  String? _error;
  var _finished = false;

  bool get _started => _startedAt != null;

  /// « le fantôme » ou « Tom ».
  String get _who => widget.rival ?? 'le fantôme';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final source = ref.read(locationSourceProvider);
    final access = await source.requestAccess();
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      setState(
        () => _error =
            'La course contre le fantôme a besoin de ta position : '
            'autorise-la dans Réglages > Running Tools > Position.',
      );
      return;
    }
    _subscription = source.fixes().listen(_onFix);
  }

  void _start() {
    setState(() {
      _startedAt = DateTime.now();
      _startDistanceM = _tracker.distanceM;
    });
    _clock.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    _voice.say(
      widget.rival == null
          ? 'Partez ! ${widget.ghost.name} est parti avec toi.'
          : 'Partez ! ${widget.rival} est parti avec toi.',
    );
  }

  void _onFix(GpsFix fix) {
    _tracker.add(fix);
    if (_started) {
      _update();
    } else {
      setState(() {});
    }
  }

  void _update() {
    if (_finished || !_started) return;
    final t = _clock.elapsed.inMilliseconds / 1000;
    var d = _tracker.distanceM - _startDistanceM;
    if (_matcher case final matcher?) {
      final position = _tracker.position;
      final along = position == null ? null : matcher.alongRoute(position);
      _offRoute = along == null;
      d = along ?? _distanceM;
    }
    final gap = gapAt(widget.ghost, timeS: t, distanceM: d);
    _curve.add(d, gap);
    final phrase = _announcer.update(timeS: t, distanceM: d, gap: gap);
    if (phrase != null) _voice.say(phrase);
    setState(() {
      _elapsedS = t;
      _distanceM = d;
      _gap = gap;
    });
    final total = widget.ghost.totalDistanceM;
    if (total != null && d >= total) _finish();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    // Arrêt net du GPS ; inutile d'attendre la fin de l'annulation.
    unawaited(_subscription?.cancel());
    _subscription = null;
    final gap = _gap ?? const GhostGap(seconds: 0, meters: 0);
    await _voice.say('Arrivée ! ${describeGap(gap)}');
    final summary = GhostRunSummary(
      date: _startedAt!,
      ghostName: widget.ghost.name,
      alignment: widget.alignment,
      distanceM: _distanceM,
      timeS: _elapsedS,
      gapS: gap.seconds,
      curve: _curve.points,
      rival: widget.rival,
    );
    final repo = await ref.read(ghostRepositoryProvider.future);
    await repo.addRun(summary);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GhostResultPage(summary: summary),
      ),
    );
  }

  Future<void> _confirmFinish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la course ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok ?? false) await _finish();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subscription?.cancel();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (signal, signalColor) = signalQuality(_tracker.accuracyM);
    final gap = _gap;
    final total = widget.ghost.totalDistanceM;
    return Scaffold(
      body: Column(
        children: [
          RunHeader(
            entry: widget.rival == null ? HomeEntry.ghost : HomeEntry.duo,
            trailing: widget.rival ?? widget.ghost.name,
          ),
          Expanded(
            child: _error != null
                ? RunMessage(icon: Icons.location_off, text: _error!)
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Chip(
                          avatar: Icon(Icons.gps_fixed, color: signalColor),
                          label: Text(
                            _offRoute ? 'Hors du parcours de $_who' : signal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_started)
                        Text(
                          'Attends un bon signal GPS, puis pars : $_who '
                          'part avec toi. Les annonces passent par-dessus ta '
                          'musique.',
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        Center(
                          child: GapText(
                            seconds: gap?.seconds ?? 0,
                            style: theme.textTheme.displayLarge,
                          ),
                        ),
                        Text(
                          gap == null
                              ? 'À hauteur de $_who'
                              : gap.ahead
                              ? 'devant $_who · ${gap.meters.round()} m'
                              : 'derrière $_who · '
                                    '${gap.meters.abs().round()} m',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${(_distanceM / 1000).toStringAsFixed(2).replaceAll('.', ',')} km'
                          ' · ${formatClock(_elapsedS)}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (total != null)
                          Text(
                            'Reste ${((total - _distanceM).clamp(0, total) / 1000).toStringAsFixed(2).replaceAll('.', ',')} km',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                      ],
                    ],
                  ),
          ),
          if (_error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _started
                    ? OutlinedButton.icon(
                        onPressed: _confirmFinish,
                        icon: const Icon(Icons.flag),
                        label: const Text('Terminer'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(64),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _tracker.accuracyM == null ? null : _start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Partir'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(64),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
