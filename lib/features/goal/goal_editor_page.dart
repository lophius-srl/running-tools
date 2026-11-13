import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_repository.dart';
import '../../data/providers.dart';
import '../../domain/goal/race_goal.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import '../course/course_text.dart';

/// Créer ou modifier l'objectif.
class GoalEditorPage extends ConsumerStatefulWidget {
  const GoalEditorPage({super.key, this.goal});

  final RaceGoal? goal;

  @override
  ConsumerState<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends ConsumerState<GoalEditorPage> {
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _km = TextEditingController(
    text: widget.goal == null
        ? ''
        : formatDecimal(
            double.parse((widget.goal!.distanceM / 1000).toStringAsFixed(3)),
          ),
  );
  late final _target = TextEditingController(
    text: widget.goal?.targetTime == null
        ? ''
        : formatRaceTime(widget.goal!.targetTime!.inSeconds.toDouble()),
  );
  late DateTime? _date = widget.goal?.date;

  /// Distance exacte d'un choix proposé (le champ l'affiche arrondie).
  late double? _presetM = commonRaceDistances
      .map((d) => d.$2)
      .where((m) => m == widget.goal?.distanceM)
      .firstOrNull;
  late String? _courseId = widget.goal?.courseId;
  var _courses = <SavedCourse>[];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final repo = await ref.read(courseRepositoryProvider.future);
    final courses = await repo.all();
    if (mounted) setState(() => _courses = courses);
  }

  @override
  void dispose() {
    _name.dispose();
    _km.dispose();
    _target.dispose();
    super.dispose();
  }

  double? get _distanceM {
    if (_presetM case final m?) return m;
    final km = parseDecimal(_km.text);
    return km == null || km <= 0 ? null : km * 1000;
  }

  /// Temps visé : vide = aucun ; sinon h:mm:ss ou mm:ss.
  ({bool valid, Duration? value}) get _targetTime {
    final text = _target.text.trim();
    if (text.isEmpty) return (valid: true, value: null);
    final d = parseClock(text);
    return d == null || d < const Duration(minutes: 5)
        ? (valid: false, value: null)
        : (valid: true, value: d);
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _date != null &&
      _distanceM != null &&
      _targetTime.valid;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 60)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _pickCourse(String? id) {
    setState(() {
      _courseId = id;
      _presetM = null;
    });
    final course = _courses.where((c) => c.id == id).firstOrNull;
    if (course != null) {
      _km.text = formatDecimal(
        double.parse((course.profile.distanceM / 1000).toStringAsFixed(1)),
      );
      if (_name.text.trim().isEmpty) _name.text = course.profile.name;
    }
  }

  Future<void> _save() async {
    final base = widget.goal;
    final goal = RaceGoal(
      id: base?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      date: _date!,
      distanceM: _distanceM!,
      targetTime: _targetTime.value,
      courseId: _courseId,
      debriefId: base?.debriefId,
    );
    final repo = await ref.read(goalRepositoryProvider.future);
    await repo.save(goal);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = _distanceM;
    final target = _targetTime;
    final pace = distance != null && target.value != null
        ? RaceGoal(
            id: '',
            name: '',
            date: DateTime(2000),
            distanceM: distance,
            targetTime: target.value,
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'Nouvel objectif' : 'Mon objectif'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('goal-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Course',
              hintText: 'Semi de Lyon',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Date'),
            trailing: Text(
              _date == null
                  ? 'Choisir'
                  : formatDateTime(_date!).split(',').first,
              style: theme.textTheme.titleMedium,
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 4),
          Text('Distance', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, m) in commonRaceDistances)
                ChoiceChip(
                  label: Text(label),
                  selected: distance == m,
                  onSelected: (_) => setState(() {
                    _presetM = m;
                    _km.text = formatDecimal(m / 1000);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('goal-km'),
            controller: _km,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'ou une autre distance',
              suffixText: 'km',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _presetM = null),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('goal-target'),
            controller: _target,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: 'Temps visé (facultatif)',
              hintText: '1:45:00',
              helperText: pace == null
                  ? null
                  : 'Allure ${targetPaceText(pace)}',
              errorText: target.valid ? null : 'Format h:mm:ss ou mm:ss',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_courses.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _courseId,
              decoration: const InputDecoration(
                labelText: 'Parcours GPX (facultatif)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                for (final c in _courses)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.profile.name} · ${formatKm(c.profile.distanceM)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _pickCourse,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _valid ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
