import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/checklist.dart';
import '../common/date_text.dart';
import 'checklists_controller.dart';

/// Checklist d'une course : cocher, ajouter, tout décocher, rappel.
class RaceChecklistPage extends ConsumerStatefulWidget {
  const RaceChecklistPage({super.key, required this.checklistId});

  final String checklistId;

  @override
  ConsumerState<RaceChecklistPage> createState() => _RaceChecklistPageState();
}

class _RaceChecklistPageState extends ConsumerState<RaceChecklistPage> {
  final _newItem = TextEditingController();

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  ChecklistsController get _controller =>
      ref.read(checklistsControllerProvider.notifier);

  Future<void> _editReminder(RaceChecklist race) async {
    final r = race.reminder;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r?.hour ?? 20, minute: r?.minute ?? 0),
      helpText: 'Rappel la veille à',
    );
    if (picked == null) return;
    await _controller.saveRace(
      race.withReminder((hour: picked.hour, minute: picked.minute)),
    );
  }

  Future<void> _delete(RaceChecklist race) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${race.raceName} » ?'),
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
    await _controller.deleteRace(race.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checklistsControllerProvider).value;
    final race = state?.race(widget.checklistId);
    if (race == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: state == null
              ? const CircularProgressIndicator()
              : const Text('Checklist introuvable.'),
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missing = race.missingMandatory.length;
    final reminder = race.reminder;

    return Scaffold(
      appBar: AppBar(
        title: Text(race.raceName),
        actions: [
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(race),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${race.checkedCount}/${race.items.length} prêts',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: race.progress,
              minHeight: 12,
              color: race.isComplete ? const Color(0xFF15803D) : null,
            ),
          ),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$missing élément(s) obligatoire(s) manquant(s)',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(
              reminder == null
                  ? 'Pas de rappel'
                  : 'Rappel la veille à '
                        '${reminder.hour}h${reminder.minute.toString().padLeft(2, '0')}',
            ),
            subtitle: Text(
              'Course le ${formatDateTime(race.raceDate).split(',').first}',
            ),
            trailing: reminder == null
                ? TextButton(
                    onPressed: () => _editReminder(race),
                    child: const Text('Ajouter'),
                  )
                : IconButton(
                    tooltip: 'Retirer le rappel',
                    icon: const Icon(Icons.notifications_off_outlined),
                    onPressed: () =>
                        _controller.saveRace(race.withReminder(null)),
                  ),
            onTap: () => _editReminder(race),
          ),
          for (final (i, item) in race.items.indexed)
            Card(
              color: scheme.surfaceContainerLowest,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: CheckboxListTile(
                value: item.checked,
                onChanged: (_) => _controller.edit(race.id, (r) => r.toggle(i)),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 18,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: item.mandatory
                    ? Text(
                        'Obligatoire',
                        style: TextStyle(
                          color: item.checked ? null : scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
                secondary: IconButton(
                  tooltip: 'Retirer ${item.label}',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      _controller.edit(race.id, (r) => r.removeItem(i)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _newItem,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ajouter un élément',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Ajouter',
                icon: const Icon(Icons.add),
                onPressed: () {
                  final text = _newItem.text;
                  _controller.edit(race.id, (r) => r.addItem(text));
                  _newItem.clear();
                },
              ),
            ),
            onSubmitted: (text) {
              _controller.edit(race.id, (r) => r.addItem(text));
              _newItem.clear();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: race.checkedCount == 0
                ? null
                : () => _controller.edit(race.id, (r) => r.uncheckAll()),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Tout décocher'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
