import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/checklist.dart';
import 'checklists_controller.dart';

/// Création ou modification d'un modèle (un modèle fourni se duplique).
class TemplateEditorPage extends ConsumerStatefulWidget {
  const TemplateEditorPage({super.key, this.initial});

  final ChecklistTemplate? initial;

  @override
  ConsumerState<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends ConsumerState<TemplateEditorPage> {
  late final _name = TextEditingController(
    text: switch (widget.initial) {
      null => 'Mon modèle',
      final t when t.builtIn => '${t.name} (perso)',
      final t => t.name,
    },
  );
  late final _items = [...?widget.initial?.items];
  final _newItem = TextEditingController();

  bool get _builtIn => widget.initial?.builtIn ?? false;

  @override
  void dispose() {
    _name.dispose();
    _newItem.dispose();
    super.dispose();
  }

  void _add() {
    final label = _newItem.text.trim();
    if (label.isEmpty || _items.any((i) => i.label == label)) return;
    setState(() => _items.add(TemplateItem(label)));
    _newItem.clear();
  }

  Future<void> _save() async {
    final initial = widget.initial;
    final keepId = initial != null && !initial.builtIn;
    await ref
        .read(checklistsControllerProvider.notifier)
        .saveTemplate(
          ChecklistTemplate(
            id: keepId
                ? initial.id
                : 'tpl-${DateTime.now().microsecondsSinceEpoch}',
            name: _name.text.trim(),
            items: _items,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref
        .read(checklistsControllerProvider.notifier)
        .deleteTemplate(widget.initial!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty && _items.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(_builtIn ? 'Dupliquer le modèle' : 'Modèle'),
        actions: [
          if (widget.initial != null && !_builtIn)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: valid ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(
              _builtIn ? 'Enregistrer comme mon modèle' : 'Enregistrer',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nom du modèle',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          for (final (i, item) in _items.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.label),
              leading: IconButton(
                tooltip: item.mandatory
                    ? 'Rendre facultatif'
                    : 'Rendre obligatoire',
                icon: Icon(
                  item.mandatory
                      ? Icons.priority_high
                      : Icons.check_box_outline_blank,
                  color: item.mandatory
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                onPressed: () => setState(
                  () => _items[i] = TemplateItem(
                    item.label,
                    mandatory: !item.mandatory,
                  ),
                ),
              ),
              trailing: IconButton(
                tooltip: 'Retirer ${item.label}',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ),
          TextField(
            controller: _newItem,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ajouter un élément',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Ajouter',
                icon: const Icon(Icons.add),
                onPressed: _add,
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
    );
  }
}
