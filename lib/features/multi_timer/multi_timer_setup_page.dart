import 'package:flutter/material.dart';

import '../../domain/multi_timer.dart';
import '../../domain/track_lanes.dart';
import '../common/decimal_text.dart';
import '../common/lane_selector.dart';
import 'multi_timer_page.dart';

enum _Target { laps, distance }

/// Préparation du chrono : coureurs, tours ou distance, couloir.
class MultiTimerSetupPage extends StatefulWidget {
  const MultiTimerSetupPage({super.key});

  @override
  State<MultiTimerSetupPage> createState() => _MultiTimerSetupPageState();
}

class _MultiTimerSetupPageState extends State<MultiTimerSetupPage> {
  static const _track = TrackGeometry.standard;

  final _names = [
    for (var i = 1; i <= 4; i++) TextEditingController(text: 'Coureur $i'),
  ];
  final _target = TextEditingController(text: '4');
  var _targetKind = _Target.laps;
  var _lane = 1;

  @override
  void dispose() {
    for (final c in [..._names, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _lapLength => _track.lapLengthM(_lane);

  /// Nombre de tours visé ; `null` si la saisie est invalide.
  int? get _laps {
    final value = parseDecimal(_target.text);
    if (value == null || value <= 0) return null;
    return switch (_targetKind) {
      _Target.laps => value == value.roundToDouble() ? value.round() : null,
      _Target.distance => lapsForDistance(value, _lapLength),
    };
  }

  List<String> get _runnerNames => [
    for (final (i, c) in _names.indexed)
      c.text.trim().isEmpty ? 'Coureur ${i + 1}' : c.text.trim(),
  ];

  @override
  Widget build(BuildContext context) {
    final laps = _laps;
    return Scaffold(
      appBar: AppBar(title: const Text('Chrono multi-coureurs')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: laps == null
                ? null
                : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => MultiTimerPage(
                        names: _runnerNames,
                        targetLaps: laps,
                        lapLengthM: _lapLength,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.timer),
            label: Text(
              laps == null ? 'Objectif invalide' : 'Prêt : $laps tour(s)',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Coureurs', style: Theme.of(context).textTheme.titleMedium),
          for (final (i, c) in _names.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: c,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _names.length > 1
                      ? IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _names.removeAt(i).dispose()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_names.length < 12)
            TextButton.icon(
              onPressed: () => setState(
                () => _names.add(
                  TextEditingController(text: 'Coureur ${_names.length + 1}'),
                ),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter un coureur'),
            ),
          const SizedBox(height: 16),
          SegmentedButton<_Target>(
            segments: const [
              ButtonSegment(value: _Target.laps, label: Text('Tours')),
              ButtonSegment(value: _Target.distance, label: Text('Distance')),
            ],
            selected: {_targetKind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _targetKind = s.single;
              _target.text = s.single == _Target.laps ? '4' : '1600';
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _targetKind == _Target.laps
                  ? 'Nombre de tours'
                  : 'Distance (tour entamé = tour compté)',
              suffixText: _targetKind == _Target.laps ? 'tours' : 'm',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            'Couloir (tour de ${formatDecimal((_lapLength * 100).round() / 100)} m)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LaneSelector(
            selected: _lane,
            onChanged: (lane) => setState(() => _lane = lane),
          ),
        ],
      ),
    );
  }
}
