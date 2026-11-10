import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device/location_source.dart';
import '../../domain/gps_tracker.dart';
import '../../domain/training_paces.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';

/// Suivi GPS en direct, pour vérifier la brique avant le fantôme et le duo.
/// Rien n'est enregistré.
class GpsCheckPage extends ConsumerStatefulWidget {
  const GpsCheckPage({super.key});

  @override
  ConsumerState<GpsCheckPage> createState() => _GpsCheckPageState();
}

class _GpsCheckPageState extends ConsumerState<GpsCheckPage> {
  StreamSubscription<GpsFix>? _subscription;
  Timer? _ticker;
  GpsTracker? _tracker;
  DateTime? _startedAt;
  var _elapsed = Duration.zero;
  String? _error;

  bool get _running => _subscription != null;

  Future<void> _start() async {
    final source = ref.read(locationSourceProvider);
    final access = await source.requestAccess();
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      setState(
        () => _error = access == LocationAccess.disabled
            ? 'Le service de localisation est désactivé (Réglages > '
                  'Confidentialité > Service de localisation).'
            : 'Accès à la position refusé : autorise-le dans Réglages > '
                  'Running Tools > Position.',
      );
      return;
    }
    final tracker = GpsTracker();
    setState(() {
      _error = null;
      _tracker = tracker;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _subscription = source.fixes().listen((fix) {
        tracker.add(fix);
        setState(() {});
      });
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) =>
            setState(() => _elapsed = DateTime.now().difference(_startedAt!)),
      );
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    await _subscription?.cancel();
    if (mounted) {
      setState(() {
        _ticker = null;
        _subscription = null;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.gps),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (tracker == null)
                  const Text(
                    'Lance le suivi puis cours : distance et allure en '
                    'direct, même écran verrouillé. Aucun parcours n’est '
                    'enregistré.',
                    textAlign: TextAlign.center,
                  )
                else
                  _Readings(tracker: tracker, elapsed: _elapsed),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? 'Arrêter' : 'Démarrer le suivi'),
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

/// Qualité du signal, d'après la précision annoncée par le GPS.
(String, Color) signalQuality(double? accuracyM) => switch (accuracyM) {
  null => ('Recherche du signal…', Colors.grey),
  <= 8 => ('Signal GPS bon', const Color(0xFF15803D)),
  <= 15 => ('Signal GPS moyen', const Color(0xFFD97706)),
  _ => ('Signal GPS faible', const Color(0xFFDC2626)),
};

class _Readings extends StatelessWidget {
  const _Readings({required this.tracker, required this.elapsed});

  final GpsTracker tracker;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final big = theme.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final km = tracker.distanceM / 1000;
    final average = km < 0.05 || elapsed.inSeconds < 10
        ? '–'
        : formatPace(paceForSpeed(km / (elapsed.inSeconds / 3600)));
    final speedKmh = tracker.speedMps * 3.6;
    final current = speedKmh < 3.6 ? '–' : formatPace(paceForSpeed(speedKmh));
    final (label, color) = signalQuality(tracker.accuracyM);
    return Column(
      children: [
        Chip(
          avatar: Icon(Icons.gps_fixed, color: color),
          label: Text(
            tracker.accuracyM == null
                ? label
                : '$label (±${tracker.accuracyM!.round()} m)',
          ),
        ),
        const SizedBox(height: 16),
        Text('${km.toStringAsFixed(2).replaceAll('.', ',')} km', style: big),
        Text(formatClock(elapsed.inSeconds.toDouble()), style: big),
        const SizedBox(height: 16),
        Text(
          'Allure actuelle : $current /km',
          style: theme.textTheme.titleLarge,
        ),
        Text(
          'Allure moyenne : $average /km',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('${tracker.rejected} point(s) GPS écarté(s)'),
      ],
    );
  }
}
