import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../data/providers.dart';
import '../../domain/stage_protocol.dart';
import '../../domain/staged_test_setup.dart';
import '../common/decimal_text.dart';
import 'club_run_page.dart';

/// Préparation d'un test de groupe : test, participants.
class ClubSetupPage extends ConsumerStatefulWidget {
  const ClubSetupPage({super.key});

  @override
  ConsumerState<ClubSetupPage> createState() => _ClubSetupPageState();
}

class _ClubSetupPageState extends ConsumerState<ClubSetupPage> {
  final _name = TextEditingController();
  final _participants = <String>[];
  var _recent = <String>[];
  var _test = StagedTest.vameval;
  StagedTestSetup? _setup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await (await ref.read(recentNamesRepositoryProvider.future))
        .recent();
    if (mounted) setState(() => _recent = names);
    await _loadSetup();
  }

  /// Réglages du dernier test solo de ce type, sinon les réglages officiels.
  Future<void> _loadSetup() async {
    final saved = await (await ref.read(setupRepositoryProvider.future))
        .load(_test);
    if (mounted) {
      setState(() => _setup = saved ?? StagedTestSetup.defaults(_test));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add(String name) {
    final n = name.trim();
    if (n.isEmpty || _participants.contains(n)) return;
    setState(() => _participants.add(n));
    _name.clear();
  }

  Future<void> _start(StagedTestSetup setup) async {
    final names = await ref.read(recentNamesRepositoryProvider.future);
    await names.remember(_participants);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ClubRunPage(setup: setup, names: [..._participants]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = _setup;
    final suggestions = [
      for (final n in _recent)
        if (!_participants.contains(n)) n,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Test de groupe')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: setup == null || _participants.isEmpty
                ? null
                : () => _start(setup),
            icon: const Icon(Icons.groups),
            label: Text(
              _participants.isEmpty
                  ? 'Ajoute des participants'
                  : 'Démarrer avec ${_participants.length} coureur(s)',
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
          SegmentedButton<StagedTest>(
            segments: [
              for (final t in StagedTest.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_test},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() {
                _test = s.single;
                _setup = null;
              });
              _loadSetup();
            },
          ),
          if (setup != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Repères tous les ${formatDecimal(setup.protocol.markerSpacingM)} m, '
                'départ ${formatKmh(setup.protocol.startSpeedKmh)} km/h '
                '(réglages du dernier test solo)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          Text('Participants', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nom',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Ajouter',
                icon: const Icon(Icons.add),
                onPressed: () => _add(_name.text),
              ),
            ),
            onSubmitted: _add,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final n in _participants)
                InputChip(
                  label: Text(n),
                  onDeleted: () => setState(() => _participants.remove(n)),
                ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Récents', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final n in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(n),
                    onPressed: () => _add(n),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
