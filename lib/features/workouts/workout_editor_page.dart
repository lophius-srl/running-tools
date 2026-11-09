import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/workout.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import 'workouts_controller.dart';

enum _Amount { distance, time }

enum _Rest { none, time, distance }

/// Une série en cours d'édition.
class _SetDraft {
  _SetDraft.from(WorkoutSet set)
    : reps = TextEditingController(text: '${set.reps}'),
      amountKind = set.effort.isDistance ? _Amount.distance : _Amount.time,
      amount = TextEditingController(
        text: set.effort.isDistance
            ? formatDecimal(set.effort.distanceM!)
            : _clock(set.effort.duration!),
      ),
      percent = TextEditingController(
        text: set.effort.percentVma == null
            ? ''
            : formatDecimal(set.effort.percentVma!),
      ),
      restKind = switch (set.recovery) {
        null => _Rest.none,
        Recovery(distanceM: _?) => _Rest.distance,
        _ => _Rest.time,
      },
      rest = TextEditingController(
        text: switch (set.recovery) {
          Recovery(distanceM: final d?) => formatDecimal(d),
          Recovery(duration: final d?) => _clock(d),
          _ => '1:00',
        },
      );

  final TextEditingController reps;
  _Amount amountKind;
  final TextEditingController amount;
  final TextEditingController percent;
  _Rest restKind;
  final TextEditingController rest;

  List<TextEditingController> get controllers => [reps, amount, percent, rest];

  /// La série saisie ; `null` si un champ est invalide.
  WorkoutSet? get value {
    final count = int.tryParse(reps.text.trim());
    final pct = percent.text.trim().isEmpty ? null : parseDecimal(percent.text);
    if (count == null || count < 1) return null;
    if (percent.text.trim().isNotEmpty && (pct == null || pct <= 0)) {
      return null;
    }
    final Effort effort;
    switch (amountKind) {
      case _Amount.distance:
        final d = parseDecimal(amount.text);
        // Une répétition en distance a besoin d'une allure pour être chronométrée.
        if (d == null || d <= 0 || pct == null) return null;
        effort = Effort.distance(d, percentVma: pct);
      case _Amount.time:
        final t = parseClock(amount.text);
        if (t == null || t <= Duration.zero) return null;
        effort = Effort.time(t, percentVma: pct);
    }
    final Recovery? recovery;
    switch (restKind) {
      case _Rest.none:
        recovery = null;
      case _Rest.time:
        final t = parseClock(rest.text);
        if (t == null || t <= Duration.zero) return null;
        recovery = Recovery.time(t);
      case _Rest.distance:
        final d = parseDecimal(rest.text);
        if (d == null || d <= 0) return null;
        recovery = Recovery.distance(d);
    }
    return WorkoutSet(reps: count, effort: effort, recovery: recovery);
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Création ou modification d'une séance personnelle.
class WorkoutEditorPage extends ConsumerStatefulWidget {
  const WorkoutEditorPage({super.key, this.initial, this.duplicate = false});

  /// Séance de départ ; `null` pour une séance vierge.
  final Workout? initial;

  /// Enregistrer comme nouvelle séance (copie) plutôt que remplacer.
  final bool duplicate;

  @override
  ConsumerState<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends ConsumerState<WorkoutEditorPage> {
  static const _blank = WorkoutSet(
    reps: 6,
    effort: Effort.distance(400, percentVma: 100),
    recovery: Recovery.time(Duration(minutes: 1, seconds: 30)),
  );

  late final _name = TextEditingController(
    text: switch (widget.initial) {
      null => 'Ma séance',
      final w when widget.duplicate => '${w.name} (copie)',
      final w => w.name,
    },
  );
  late final _sets = [
    for (final s in widget.initial?.sets ?? const [_blank]) _SetDraft.from(s),
  ];
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final s in _sets) {
      for (final c in s.controllers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Workout? get _workout {
    final name = _name.text.trim();
    final sets = _sets.map((s) => s.value).toList();
    if (name.isEmpty || sets.isEmpty || sets.contains(null)) return null;
    final initial = widget.initial;
    final keepId = initial != null && !initial.builtIn && !widget.duplicate;
    return Workout(
      id: keepId
          ? initial.id
          : 'perso-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      sets: sets.cast<WorkoutSet>(),
    );
  }

  Future<void> _save(Workout workout) async {
    setState(() => _saving = true);
    await ref.read(workoutsControllerProvider.notifier).save(workout);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _text(
    TextEditingController c,
    String label, {
    String? suffix,
    String? hint,
    TextInputType keyboard = const TextInputType.numberWithOptions(
      decimal: true,
    ),
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nouvelle séance' : 'Séance'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _text(_name, 'Nom', keyboard: TextInputType.text),
          for (var i = 0; i < _sets.length; i++) _setCard(i, theme),
          TextButton.icon(
            onPressed: () => setState(
              () => _sets.add(_SetDraft.from(_sets.last.value ?? _blank)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une série'),
          ),
          const SizedBox(height: 12),
          if (workout == null)
            Text(
              'Vérifie les champs : une répétition en distance a besoin d’un '
              '% VMA ; durées au format 1:30.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: workout == null || _saving ? null : () => _save(workout),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _setCard(int i, ThemeData theme) {
    final set = _sets[i];
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Série ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_sets.length > 1)
                  IconButton(
                    tooltip: 'Retirer la série',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _sets.removeAt(i)),
                  ),
              ],
            ),
            SegmentedButton<_Amount>(
              segments: const [
                ButtonSegment(value: _Amount.distance, label: Text('Distance')),
                ButtonSegment(value: _Amount.time, label: Text('Durée')),
              ],
              selected: {set.amountKind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                set.amountKind = s.single;
                set.amount.text = s.single == _Amount.distance ? '400' : '0:30';
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _text(
                    set.reps,
                    'Répétitions',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: set.amountKind == _Amount.distance
                      ? _text(set.amount, 'Distance', suffix: 'm')
                      : _text(set.amount, 'Durée', hint: '0:30'),
                ),
                const SizedBox(width: 8),
                Expanded(child: _text(set.percent, '% VMA', suffix: '%')),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<_Rest>(
              segments: const [
                ButtonSegment(value: _Rest.none, label: Text('Sans récup')),
                ButtonSegment(value: _Rest.time, label: Text('Récup temps')),
                ButtonSegment(value: _Rest.distance, label: Text('Récup m')),
              ],
              selected: {set.restKind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                set.restKind = s.single;
                set.rest.text = s.single == _Rest.distance ? '200' : '1:00';
              }),
            ),
            if (set.restKind != _Rest.none) ...[
              const SizedBox(height: 10),
              set.restKind == _Rest.time
                  ? _text(set.rest, 'Récupération', hint: '1:30')
                  : _text(set.rest, 'Récupération trottinée', suffix: 'm'),
            ],
          ],
        ),
      ),
    );
  }
}
