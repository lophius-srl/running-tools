import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/checklist.dart';
import '../common/date_text.dart';
import 'checklists_controller.dart';
import 'new_race_page.dart';
import 'race_checklist_page.dart';
import 'template_editor_page.dart';

/// Mes courses (checklists) et mes modèles.
class ChecklistsPage extends ConsumerWidget {
  const ChecklistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checklistsControllerProvider).value;
    final theme = Theme.of(context);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Checklists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => open(const NewRacePage()),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle course'),
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                title('Mes courses'),
                if (state.races.isEmpty)
                  const Text('Aucune course : crée-en une depuis un modèle.'),
                for (final race in state.races)
                  Card(
                    color: theme.colorScheme.surfaceContainerLowest,
                    child: ListTile(
                      title: Text(
                        race.raceName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        formatDateTime(race.raceDate).split(',').first,
                      ),
                      trailing: _Progress(race: race),
                      onTap: () =>
                          open(RaceChecklistPage(checklistId: race.id)),
                    ),
                  ),
                title('Modèles'),
                for (final t in state.templates)
                  ListTile(
                    leading: Icon(
                      t.builtIn ? Icons.inventory_2_outlined : Icons.edit_note,
                    ),
                    title: Text(t.name),
                    subtitle: Text('${t.items.length} éléments'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(TemplateEditorPage(initial: t)),
                  ),
                TextButton.icon(
                  onPressed: () => open(const TemplateEditorPage()),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau modèle'),
                ),
              ],
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.race});

  final RaceChecklist race;

  @override
  Widget build(BuildContext context) {
    final done = race.isComplete;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${race.checkedCount}/${race.items.length}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: done ? const Color(0xFF15803D) : null,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            value: race.progress,
            strokeWidth: 4,
            color: done ? const Color(0xFF15803D) : null,
          ),
        ),
      ],
    );
  }
}
