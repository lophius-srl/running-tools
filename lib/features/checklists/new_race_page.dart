import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/checklist.dart';
import '../common/date_text.dart';
import 'checklists_controller.dart';
import 'race_checklist_page.dart';

/// Nouvelle course : nom, date, modèle, rappel la veille.
class NewRacePage extends ConsumerStatefulWidget {
  const NewRacePage({super.key, this.courseId, this.initialName});

  /// Course importée dans le simulateur de parcours, le cas échéant.
  final String? courseId;
  final String? initialName;

  @override
  ConsumerState<NewRacePage> createState() => _NewRacePageState();
}

class _NewRacePageState extends ConsumerState<NewRacePage> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late DateTime _date = DateUtils.dateOnly(DateTime.now())
      .add(const Duration(days: 7));
  String _templateId = builtInTemplates.first.id;
  var _remind = true;
  var _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(List<ChecklistTemplate> templates) async {
    final template = templates.firstWhere((t) => t.id == _templateId);
    final race = RaceChecklist.fromTemplate(
      template,
      id: 'race-${DateTime.now().microsecondsSinceEpoch}',
      raceName: _name.text.trim(),
      raceDate: _date,
      reminder: _remind ? (hour: _time.hour, minute: _time.minute) : null,
      courseId: widget.courseId,
    );
    final scheduled = await ref
        .read(checklistsControllerProvider.notifier)
        .saveRace(race);
    if (!mounted) return;
    if (!scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rappel non programmé : notifications refusées.'),
        ),
      );
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RaceChecklistPage(checklistId: race.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates =
        ref.watch(checklistsControllerProvider).value?.templates ??
        builtInTemplates;
    final valid = _name.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle course')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: valid ? () => _create(templates) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Créer la checklist'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom de la course',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Date'),
            subtitle: Text(formatDateTime(_date).split(',').first),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateUtils.dateOnly(DateTime.now()),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _templateId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Modèle',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in templates)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            onChanged: (id) => setState(() => _templateId = id ?? _templateId),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rappel la veille'),
            subtitle: Text('à ${_time.format(context)}'),
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
          ),
          if (_remind)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Changer l’heure'),
              ),
            ),
        ],
      ),
    );
  }
}
