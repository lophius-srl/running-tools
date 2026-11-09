import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../audio/workout_program.dart';
import '../../data/providers.dart';
import '../../domain/training_paces.dart';
import '../../domain/workout.dart';
import '../../domain/workout_plan.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import '../common/lane_selector.dart';
import 'workout_editor_page.dart';
import 'workout_run_page.dart';
import 'workouts_controller.dart';

/// Séance appliquée à ma VMA : temps par répétition, par repère, par tour.
class WorkoutDetailPage extends ConsumerStatefulWidget {
  const WorkoutDetailPage({super.key, required this.workout});

  final Workout workout;

  @override
  ConsumerState<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends ConsumerState<WorkoutDetailPage> {
  final _vma = TextEditingController();
  final _spacing = TextEditingController(text: '20');
  var _lane = 1;

  @override
  void initState() {
    super.initState();
    _loadLastVma();
  }

  Future<void> _loadLastVma() async {
    final vma = await ref.read(lastVmaProvider.future);
    if (mounted && _vma.text.isEmpty) {
      setState(() => _vma.text = formatKmh(vma ?? 15));
    }
  }

  @override
  void dispose() {
    _vma.dispose();
    _spacing.dispose();
    super.dispose();
  }

  WorkoutPlan? get _plan {
    final vma = parseDecimal(_vma.text);
    final spacing = parseDecimal(_spacing.text);
    if (vma == null || vma <= 0 || spacing == null || spacing <= 0) {
      return null;
    }
    return WorkoutPlan.compute(
      widget.workout,
      vmaKmh: vma,
      markerSpacingM: spacing,
      lane: _lane,
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette séance ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(workoutsControllerProvider.notifier)
        .delete(widget.workout.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Après enregistrement, retour à la liste (qui montre la séance à jour).
  Future<void> _edit({required bool duplicate}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            WorkoutEditorPage(initial: widget.workout, duplicate: duplicate),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, String label, String unit) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final workout = widget.workout;
    return Scaffold(
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WorkoutRunPage(plan: plan),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Lancer (chrono)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                    if (workout.hasDistanceEfforts)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WorkoutRunPage(
                                plan: plan,
                                mode: WorkoutAudioMode.pacer,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.graphic_eq),
                          label: const Text(
                            'Lièvre sonore (bip à chaque repère)',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      appBar: AppBar(
        title: Text(workout.name),
        actions: [
          IconButton(
            tooltip: 'Dupliquer',
            icon: const Icon(Icons.copy),
            onPressed: () => _edit(duplicate: true),
          ),
          if (!workout.builtIn) ...[
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit),
              onPressed: () => _edit(duplicate: false),
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _field(_vma, 'Ma VMA', 'km/h')),
              const SizedBox(width: 12),
              Expanded(child: _field(_spacing, 'Repères', 'm')),
            ],
          ),
          const SizedBox(height: 12),
          Text('Couloir', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          LaneSelector(
            selected: _lane,
            onChanged: (lane) => setState(() => _lane = lane),
          ),
          const SizedBox(height: 16),
          if (plan == null)
            const Text('Saisis ta VMA et l’espacement des repères.')
          else ...[
            Text(
              'Durée totale : ${formatSplit(plan.totalDuration)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final step in plan.steps) _StepTile(step: step),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final PlanStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return switch (step) {
      RecoveryStep(:final duration) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Text('Récupération · ${formatSplit(duration)}', style: muted),
      ),
      final EffortStep e => Card(
        color: theme.colorScheme.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rép. ${e.index}/${e.total} · ${_what(e)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(_targets(e)),
              if (e.markerSplits.isNotEmpty)
                Text(
                  'Un repère toutes les '
                  '${formatSplit(e.markerSplits.first)}'
                  '${e.lapTime == null || (e.distanceM ?? 0) < 400 ? '' : ' · tour en ${formatSplit(e.lapTime!)}'}',
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    };
  }

  String _what(EffortStep e) {
    final effort = e.effort;
    final amount = effort.isDistance
        ? '${formatDecimal(effort.distanceM!)} m'
        : formatSplit(effort.duration!);
    final pace = effort.percentVma == null
        ? ''
        : ' à ${formatDecimal(effort.percentVma!)} %';
    return '$amount$pace';
  }

  String _targets(EffortStep e) {
    final speed = e.speedKmh;
    if (speed == null) return 'Au ressenti (pas d’allure cible)';
    final pace = '${formatPace(paceForSpeed(speed))} /km';
    return e.effort.isDistance
        ? '${formatSplit(e.duration)} · $pace'
        : '≈ ${e.distanceM!.round()} m · $pace';
  }
}
