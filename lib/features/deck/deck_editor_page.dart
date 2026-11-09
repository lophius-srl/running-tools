import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/deck.dart';
import '../../domain/workout.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import 'decks_controller.dart';

/// Composer un deck : cartes prédéfinies ou perso, récupération, limite.
class DeckEditorPage extends ConsumerStatefulWidget {
  const DeckEditorPage({super.key, this.initial});

  final Deck? initial;

  @override
  ConsumerState<DeckEditorPage> createState() => _DeckEditorPageState();
}

class _DeckEditorPageState extends ConsumerState<DeckEditorPage> {
  late final _name = TextEditingController(
    text: widget.initial?.name ?? 'Mon deck',
  );
  late final _cards = [...?widget.initial?.cards];
  late var _recovery =
      widget.initial?.recovery ?? const Duration(minutes: 1, seconds: 30);
  late var _byPoints = widget.initial?.limit is PointsLimit;
  late final _limit = TextEditingController(
    text: switch (widget.initial?.limit) {
      PointsLimit(:final points) => '$points',
      DurationLimit(:final effortTime) => '${effortTime.inMinutes}',
      null => '12',
    },
  );

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  DeckLimit? get _deckLimit {
    final v = int.tryParse(_limit.text.trim());
    if (v == null || v <= 0) return null;
    return _byPoints ? PointsLimit(v) : DurationLimit(Duration(minutes: v));
  }

  Future<void> _addCustomCard() async {
    final card = await showDialog<EffortCard>(
      context: context,
      builder: (_) => const _CustomCardDialog(),
    );
    if (card != null) setState(() => _cards.add(card));
  }

  Future<void> _save(DeckLimit limit) async {
    final initial = widget.initial;
    await ref
        .read(decksControllerProvider.notifier)
        .save(
          Deck(
            id: initial?.id ?? 'deck-${DateTime.now().microsecondsSinceEpoch}',
            name: _name.text.trim(),
            cards: _cards,
            recovery: _recovery,
            limit: limit,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final limit = _deckLimit;
    final valid =
        _name.text.trim().isNotEmpty && _cards.isNotEmpty && limit != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Composer un deck'),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref
                    .read(decksControllerProvider.notifier)
                    .delete(widget.initial!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: valid ? () => _save(limit) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Enregistrer le deck'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Récupération entre deux cartes'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in [45, 60, 90, 120, 180])
                ChoiceChip(
                  label: Text(formatSplit(Duration(seconds: s))),
                  selected: _recovery.inSeconds == s,
                  onSelected: (_) =>
                      setState(() => _recovery = Duration(seconds: s)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Durée d’effort')),
              ButtonSegment(value: true, label: Text('Budget d’intensité')),
            ],
            selected: {_byPoints},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _byPoints = s.single;
              _limit.text = s.single ? '60' : '12';
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _limit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _byPoints ? 'Budget' : 'Effort cumulé',
              suffixText: _byPoints ? 'points' : 'min',
              helperText: _byPoints
                  ? '1 min à 100 % VMA = 10 points'
                  : 'Récupérations non comprises',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Cartes (${_cards.length})'),
          for (final (i, c) in _cards.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(cardIcon(c.kind)),
              title: Text(c.title),
              trailing: IconButton(
                tooltip: 'Retirer ${c.title}',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _cards.removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Ajouter une carte'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in predefinedCards)
                ActionChip(
                  avatar: Icon(cardIcon(c.kind), size: 18),
                  label: Text(c.title),
                  onPressed: () => setState(() => _cards.add(c)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Carte perso'),
                onPressed: _addCustomCard,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData cardIcon(CardKind kind) => switch (kind) {
  CardKind.distance => Icons.straighten,
  CardKind.time => Icons.timer,
  CardKind.sprint => Icons.bolt,
  CardKind.hill => Icons.terrain,
  CardKind.joker => Icons.auto_awesome,
};

class _CustomCardDialog extends StatefulWidget {
  const _CustomCardDialog();

  @override
  State<_CustomCardDialog> createState() => _CustomCardDialogState();
}

class _CustomCardDialogState extends State<_CustomCardDialog> {
  var _distance = true;
  final _amount = TextEditingController(text: '500');
  final _percent = TextEditingController(text: '95');

  @override
  void dispose() {
    _amount.dispose();
    _percent.dispose();
    super.dispose();
  }

  EffortCard? get _card {
    final pct = parseDecimal(_percent.text);
    if (pct == null || pct <= 0) return null;
    final id = 'perso-${DateTime.now().microsecondsSinceEpoch}';
    if (_distance) {
      final d = parseDecimal(_amount.text);
      if (d == null || d <= 0) return null;
      return EffortCard(
        id: id,
        title: '${formatDecimal(d)} m à ${formatDecimal(pct)} %',
        kind: CardKind.distance,
        effort: Effort.distance(d, percentVma: pct),
      );
    }
    final t = parseClock(_amount.text);
    if (t == null || t <= Duration.zero) return null;
    return EffortCard(
      id: id,
      title: '${formatSplit(t).replaceAll(',0', '')} à ${formatDecimal(pct)} %',
      kind: CardKind.time,
      effort: Effort.time(t, percentVma: pct),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return AlertDialog(
      title: const Text('Carte perso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Distance')),
              ButtonSegment(value: false, label: Text('Durée')),
            ],
            selected: {_distance},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _distance = s.single;
              _amount.text = s.single ? '500' : '1:30';
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _distance ? 'Distance' : 'Durée',
              suffixText: _distance ? 'm' : null,
              hintText: _distance ? null : '1:30',
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Intensité',
              suffixText: '% VMA',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: card == null
              ? null
              : () => Navigator.of(context).pop(card),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
