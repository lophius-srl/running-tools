import 'package:flutter/material.dart';

import '../../audio/announcements.dart';
import '../../domain/track_lanes.dart';
import '../../domain/training_paces.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import '../home/home_entry.dart';

enum _Direction { paceToTime, timeToPace }

/// Calculateur autonome : temps de passage et allure réelle par couloir.
class LaneCalculatorPage extends StatefulWidget {
  const LaneCalculatorPage({super.key});

  @override
  State<LaneCalculatorPage> createState() => _LaneCalculatorPageState();
}

class _LaneCalculatorPageState extends State<LaneCalculatorPage> {
  static const _track = TrackGeometry.standard;

  final _distance = TextEditingController(text: '400');
  final _pace = TextEditingController(text: '4:00');
  final _time = TextEditingController(text: '1:36');
  var _lane = 1;
  var _direction = _Direction.paceToTime;

  @override
  void dispose() {
    for (final c in [_distance, _pace, _time]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    String? hint,
    String? helper,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      hintText: hint,
      helperText: helper,
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) => setState(() {}),
  );

  /// Lignes de résultat ; `null` si la saisie est incomplète.
  List<String>? get _result {
    final distance = parseDecimal(_distance.text);
    if (distance == null || distance <= 0) return null;
    final real = _track.realDistanceM(distance, _lane);
    switch (_direction) {
      case _Direction.paceToTime:
        final speed = speedFromPace(_pace.text);
        if (speed == null) return null;
        return [
          '${formatSplit(_track.splitFor(distance, _lane, speed))} '
              'en couloir $_lane',
          '${formatDecimal(_round2(real))} m réels · '
              '${formatSplit(_track.splitFor(distance, 1, speed))} en couloir 1',
        ];
      case _Direction.timeToPace:
        final time = parseClock(_time.text);
        if (time == null || time <= Duration.zero) return null;
        final speed = _track.realSpeedKmh(distance, _lane, time);
        final naive = _track.realSpeedKmh(distance, 1, time);
        return [
          '${formatPace(paceForSpeed(speed))} /km · ${formatKmh(speed)} km/h',
          'Sans correction : ${formatPace(paceForSpeed(naive))} /km '
              '(${formatDecimal(_round2(real))} m réels)',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = HomeEntry.lanes;
    final result = _result;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: entry.gradient),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Icon(entry.icon, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'Couloirs',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Couloir', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var lane = 1; lane <= _track.lanes; lane++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _LaneButton(
                            lane: lane,
                            selected: _lane == lane,
                            onTap: () => setState(() => _lane = lane),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<_Direction>(
                  segments: const [
                    ButtonSegment(
                      value: _Direction.paceToTime,
                      label: Text('Allure → temps'),
                    ),
                    ButtonSegment(
                      value: _Direction.timeToPace,
                      label: Text('Temps → allure'),
                    ),
                  ],
                  selected: {_direction},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _direction = s.single),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _distance,
                        'Distance',
                        suffix: 'm',
                        helper: 'comptée en couloir 1',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _direction == _Direction.paceToTime
                          ? _field(
                              _pace,
                              'Allure cible',
                              suffix: '/km',
                              hint: '4:00',
                            )
                          : _field(_time, 'Temps réalisé', hint: '1:36,4'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: entry.gradient),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: result == null
                      ? const Text(
                          'Saisis une distance et une allure (ex. 4:00) ou un '
                          'temps (ex. 1:36,4).',
                          style: TextStyle(color: Colors.white),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.first,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.last,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                _LapTable(track: _track, selected: _lane),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gros bouton de couloir, facile à viser en extérieur.
class _LaneButton extends StatelessWidget {
  const _LaneButton({
    required this.lane,
    required this.selected,
    required this.onTap,
  });

  final int lane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Couloir $lane',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                '$lane',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Longueur d'un tour par couloir.
class _LapTable extends StatelessWidget {
  const _LapTable({required this.track, required this.selected});

  final TrackGeometry track;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Longueur d’un tour',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var lane = 1; lane <= track.lanes; lane++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Couloir $lane',
                        style: lane == selected
                            ? const TextStyle(fontWeight: FontWeight.w800)
                            : null,
                      ),
                    ),
                    Text(
                      '${track.lapLengthM(lane).toStringAsFixed(2).replaceAll('.', ',')} m',
                      style: TextStyle(
                        fontWeight: lane == selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Piste standard : mesure à 30 cm de la lice en couloir 1, '
              'à 20 cm de la ligne intérieure ensuite.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

double _round2(double v) => (v * 100).round() / 100;
