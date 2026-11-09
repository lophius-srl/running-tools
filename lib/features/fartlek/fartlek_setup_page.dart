import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/announcements.dart';
import '../../audio/fartlek_program.dart';
import '../../data/fartlek_repository.dart';
import '../../data/providers.dart';
import '../../domain/fartlek.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import 'fartlek_run_page.dart';

/// Réglages du fartlek surprise (le tirage reste caché jusqu'au départ).
class FartlekSetupPage extends ConsumerStatefulWidget {
  const FartlekSetupPage({super.key});

  static const totals = [20, 30, 40, 50, 60, 75, 90];

  @override
  ConsumerState<FartlekSetupPage> createState() => _FartlekSetupPageState();
}

class _FartlekSetupPageState extends ConsumerState<FartlekSetupPage> {
  var _total = 40;
  var _warmup = 10;
  var _cooldown = 5;
  var _gap = const RangeValues(2, 6); // minutes
  var _burst = const RangeValues(20, 120); // secondes
  var _byPace = false;
  final _percent = TextEditingController(text: '95');
  late final _seed = TextEditingController(text: '${newFartlekSeed(Random())}');
  var _recent = <RecentFartlek>[];
  double? _vma;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await (await ref.read(fartlekRepositoryProvider.future))
        .recent();
    final vma = await ref.read(lastVmaProvider.future);
    if (mounted) {
      setState(() {
        _recent = recent;
        _vma = vma;
      });
    }
  }

  @override
  void dispose() {
    _percent.dispose();
    _seed.dispose();
    super.dispose();
  }

  FartlekSettings get _settings => FartlekSettings(
    total: Duration(minutes: _total),
    warmup: Duration(minutes: _warmup),
    cooldown: Duration(minutes: _cooldown),
    minGap: Duration(seconds: (_gap.start * 60).round()),
    maxGap: Duration(seconds: (_gap.end * 60).round()),
    minBurst: Duration(seconds: _burst.start.round()),
    maxBurst: Duration(seconds: _burst.end.round()),
    percentVma: _byPace ? parseDecimal(_percent.text) : null,
  );

  void _replay(RecentFartlek r) {
    final s = r.settings;
    setState(() {
      _total = s.total.inMinutes;
      _warmup = s.warmup.inMinutes;
      _cooldown = s.cooldown.inMinutes;
      _gap = RangeValues(s.minGap.inSeconds / 60, s.maxGap.inSeconds / 60);
      _burst = RangeValues(
        s.minBurst.inSeconds.toDouble(),
        s.maxBurst.inSeconds.toDouble(),
      );
      _byPace = s.percentVma != null;
      if (s.percentVma case final p?) _percent.text = formatDecimal(p);
      _seed.text = '${r.seed}';
    });
  }

  Future<void> _start(FartlekSettings settings, int seed) async {
    final repo = await ref.read(fartlekRepositoryProvider.future);
    await repo.remember(
      RecentFartlek(date: DateTime.now(), seed: seed, settings: settings),
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FartlekRunPage(
          plan: FartlekPlan.generate(settings, seed),
          vmaKmh: _vma,
        ),
      ),
    );
  }

  Widget _chips(List<int> values, int selected, ValueChanged<int> onSelect) =>
      Wrap(
        spacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text('$v min'),
              selected: v == selected,
              onSelected: (_) => setState(() => onSelect(v)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;
    final seed = int.tryParse(_seed.text.trim());
    final errors = [
      ...settings.validationErrors,
      if (_byPace && settings.percentVma == null) '% VMA invalide.',
      if (seed == null) 'Graine invalide (un nombre).',
    ];
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Fartlek surprise')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: errors.isEmpty ? () => _start(settings, seed!) : null,
            icon: const Icon(Icons.shuffle),
            label: const Text('C’est parti'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Des accélérations arrivent au hasard, annoncées à la voix. '
            'Rien ne se passe pendant l’échauffement et le retour au calme.',
          ),
          label('Durée totale'),
          _chips(FartlekSetupPage.totals, _total, (v) => _total = v),
          label('Échauffement'),
          _chips([5, 10, 15], _warmup, (v) => _warmup = v),
          label('Retour au calme'),
          _chips([0, 5, 10], _cooldown, (v) => _cooldown = v),
          label(
            'Entre deux accélérations : '
            '${formatDecimal(_gap.start)} à ${formatDecimal(_gap.end)} min',
          ),
          RangeSlider(
            values: _gap,
            min: 1,
            max: 10,
            divisions: 18,
            onChanged: (v) => setState(() => _gap = v),
          ),
          label(
            'Durée des accélérations : '
            '${spokenDuration(Duration(seconds: _burst.start.round()))} à '
            '${spokenDuration(Duration(seconds: _burst.end.round()))}',
          ),
          RangeSlider(
            values: _burst,
            min: 10,
            max: 180,
            divisions: 34,
            onChanged: (v) => setState(() => _burst = v),
          ),
          label('Intensité'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Vite / très vite')),
              ButtonSegment(value: true, label: Text('% VMA')),
            ],
            selected: {_byPace},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _byPace = s.single),
          ),
          if (_byPace) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _percent,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Allure des accélérations',
                suffixText: '% VMA',
                helperText: _vma == null
                    ? 'Fais un test VMA pour annoncer une allure'
                    : 'VMA du dernier test : ${formatKmh(_vma!)} km/h',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          label('Graine (même graine = même séance)'),
          TextField(
            key: const Key('fartlek-seed'),
            controller: _seed,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
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
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_recent.isNotEmpty) ...[
            label('Rejouer une séance récente'),
            for (final r in _recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.replay),
                title: Text(
                  '${spokenDuration(r.settings.total)} · graine ${r.seed}',
                ),
                subtitle: Text(formatDateTime(r.date)),
                onTap: () => _replay(r),
              ),
          ],
        ],
      ),
    );
  }
}
