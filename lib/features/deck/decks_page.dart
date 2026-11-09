import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../data/providers.dart';
import '../../domain/deck.dart';
import '../../domain/fartlek.dart';
import '../../domain/workout_plan.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import '../common/lane_selector.dart';
import 'deck_editor_page.dart';
import 'deck_run_page.dart';
import 'decks_controller.dart';

/// Mes decks de fractionné.
class DecksPage extends ConsumerWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksControllerProvider).value ?? const [];
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: const Text('Deck de fractionné')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => open(const DeckEditorPage()),
        icon: const Icon(Icons.add),
        label: const Text('Composer'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final d in decks)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: ListTile(
                leading: const Icon(Icons.style, size: 32),
                title: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${d.cards.length} cartes · ${describeLimit(d.limit)} · '
                  'récup ${formatSplit(d.recovery)}',
                ),
                trailing: d.builtIn
                    ? null
                    : IconButton(
                        tooltip: 'Modifier ${d.name}',
                        icon: const Icon(Icons.edit),
                        onPressed: () => open(DeckEditorPage(initial: d)),
                      ),
                onTap: () => open(DeckLaunchPage(deck: d)),
              ),
            ),
        ],
      ),
    );
  }
}

String describeLimit(DeckLimit limit) => switch (limit) {
  PointsLimit(:final points) => '$points points',
  DurationLimit(:final effortTime) => '${effortTime.inMinutes} min d’effort',
};

/// Avant le tirage : VMA, repères, couloir, graine.
class DeckLaunchPage extends ConsumerStatefulWidget {
  const DeckLaunchPage({super.key, required this.deck});

  final Deck deck;

  @override
  ConsumerState<DeckLaunchPage> createState() => _DeckLaunchPageState();
}

class _DeckLaunchPageState extends ConsumerState<DeckLaunchPage> {
  final _vma = TextEditingController();
  final _spacing = TextEditingController(text: '20');
  late final _seed = TextEditingController(text: '${newFartlekSeed(Random())}');
  var _lane = 1;

  @override
  void initState() {
    super.initState();
    _loadVma();
  }

  Future<void> _loadVma() async {
    final vma = await ref.read(lastVmaProvider.future);
    if (mounted && _vma.text.isEmpty) {
      setState(() => _vma.text = formatKmh(vma ?? 15));
    }
  }

  @override
  void dispose() {
    for (final c in [_vma, _spacing, _seed]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {String? suffix}) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final vma = parseDecimal(_vma.text);
    final spacing = parseDecimal(_spacing.text);
    final seed = int.tryParse(_seed.text.trim());
    final valid =
        vma != null &&
        vma > 0 &&
        spacing != null &&
        spacing > 0 &&
        seed != null &&
        widget.deck.cards.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.name)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: valid
                ? () {
                    final draw = DeckDraw.draw(
                      widget.deck,
                      seed: seed,
                      vmaKmh: vma,
                    );
                    final plan = WorkoutPlan.compute(
                      draw.toWorkout(id: 'deck', name: widget.deck.name),
                      vmaKmh: vma,
                      markerSpacingM: spacing,
                      lane: _lane,
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => DeckRunPage(draw: draw, plan: plan),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.style),
            label: const Text('Mélanger et jouer'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.deck.cards.length} cartes, ${describeLimit(widget.deck.limit)}, '
            'récupération ${formatSplit(widget.deck.recovery)} entre deux cartes.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_vma, 'Ma VMA', suffix: 'km/h')),
              const SizedBox(width: 12),
              Expanded(child: _field(_spacing, 'Repères', suffix: 'm')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Couloir'),
          const SizedBox(height: 6),
          LaneSelector(
            selected: _lane,
            onChanged: (lane) => setState(() => _lane = lane),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('deck-seed'),
            controller: _seed,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Graine (même graine = même tirage)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Nouvelle graine',
                icon: const Icon(Icons.casino),
                onPressed: () =>
                    setState(() => _seed.text = '${newFartlekSeed(Random())}'),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
