import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/marker_spacing.dart';
import '../../domain/measurement_method.dart';
import '../../domain/stage_protocol.dart';
import '../../domain/staged_test_setup.dart';
import '../common/decimal_text.dart';
import '../home/home_entry.dart';
import '../setup_assistant/spacing_assistant_page.dart';
import '../staged_run/staged_run_page.dart';

/// Réglages d'un test par paliers avant le départ.
class StagedSetupPage extends ConsumerStatefulWidget {
  const StagedSetupPage({super.key, required this.test, this.initialChoice});

  final StagedTest test;

  /// Espacement choisi dans l'assistant, prioritaire sur les réglages mémorisés.
  final SpacingChoice? initialChoice;

  @override
  ConsumerState<StagedSetupPage> createState() => _StagedSetupPageState();
}

class _StagedSetupPageState extends ConsumerState<StagedSetupPage> {
  final _startSpeed = TextEditingController();
  final _increment = TextEditingController();
  final _stageSeconds = TextEditingController();
  final _spacing = TextEditingController();
  final _maxSpeed = TextEditingController();
  late MeasurementMethod _method;

  @override
  void initState() {
    super.initState();
    _fill(StagedTestSetup.defaults(widget.test));
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final repository = await ref.read(setupRepositoryProvider.future);
    final saved = await repository.load(widget.test);
    if (saved != null && mounted) setState(() => _fill(saved));
    if (widget.initialChoice case final choice? when mounted) {
      setState(() => _applyChoice(choice));
    }
  }

  void _applyChoice(SpacingChoice choice) {
    _spacing.text = formatDecimal(choice.spacingM);
    _method = choice.method;
  }

  Future<void> _openAssistant() async {
    final choice = await Navigator.of(context).push<SpacingChoice>(
      MaterialPageRoute(builder: (_) => const SpacingAssistantPage()),
    );
    if (choice != null && mounted) setState(() => _applyChoice(choice));
  }

  void _fill(StagedTestSetup setup) {
    final p = setup.protocol;
    _startSpeed.text = formatDecimal(p.startSpeedKmh);
    _increment.text = formatDecimal(p.incrementKmh);
    _stageSeconds.text = formatDecimal(p.stageSeconds);
    _spacing.text = formatDecimal(p.markerSpacingM);
    _maxSpeed.text = formatDecimal(setup.maxSpeedKmh);
    _method = setup.method;
  }

  @override
  void dispose() {
    for (final c in [
      _startSpeed,
      _increment,
      _stageSeconds,
      _spacing,
      _maxSpeed,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Réglages saisis ; `null` si un champ n'est pas un nombre.
  StagedTestSetup? get _setup {
    final values = [
      _startSpeed,
      _increment,
      _stageSeconds,
      _spacing,
      _maxSpeed,
    ].map((c) => parseDecimal(c.text)).toList();
    if (values.contains(null)) return null;
    return StagedTestSetup(
      test: widget.test,
      protocol: StageProtocol(
        startSpeedKmh: values[0]!,
        incrementKmh: values[1]!,
        stageDuration: Duration(milliseconds: (values[2]! * 1000).round()),
        markerSpacingM: values[3]!,
      ),
      maxSpeedKmh: values[4]!,
      method: _method,
    );
  }

  Future<void> _start(StagedTestSetup setup) async {
    final repository = await ref.read(setupRepositoryProvider.future);
    await repository.save(setup);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StagedRunPage(setup: setup)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final errors = setup == null
        ? ['Tous les champs doivent contenir un nombre.']
        : setup.validationErrors;
    final scheme = Theme.of(context).colorScheme;

    Widget field(TextEditingController c, String label, String unit) =>
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

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            test: widget.test,
            onReset: () =>
                setState(() => _fill(StagedTestSetup.defaults(widget.test))),
          ),
          _Section(
            title: 'Terrain',
            icon: Icons.straighten,
            children: [
              field(_spacing, 'Espacement des repères', 'm'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openAssistant,
                  icon: const Icon(Icons.straighten),
                  label: const Text('Mesurer mes repères'),
                ),
              ),
              DropdownButtonFormField<MeasurementMethod>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mesuré avec',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in MeasurementMethod.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _method = m ?? _method),
              ),
            ],
          ),
          _Section(
            title: 'Paliers',
            icon: Icons.trending_up,
            children: [
              Row(
                children: [
                  Expanded(
                    child: field(_startSpeed, 'Vitesse de départ', 'km/h'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: field(_increment, 'Incrément', 'km/h')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: field(_stageSeconds, 'Durée de palier', 's')),
                  const SizedBox(width: 12),
                  Expanded(child: field(_maxSpeed, 'Vitesse max', 'km/h')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: errors.isEmpty
                ? _Preview(setup: setup!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in errors)
                        Text(e, style: TextStyle(color: scheme.error)),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: FilledButton.icon(
              onPressed: errors.isEmpty ? () => _start(setup!) : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                textStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.test, required this.onReset});

  final StagedTest test;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final entry = HomeEntry.ofStagedTest(test);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: entry.gradient,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackButton(color: Colors.white),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Réglages officiels',
                    icon: const Icon(Icons.restart_alt, color: Colors.white),
                    onPressed: onReset,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(entry.icon, color: Colors.white, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.label,
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Réglages du test',
                            style: textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            for (final child in children) ...[
              const SizedBox(height: 14),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.setup});

  final StagedTestSetup setup;

  @override
  Widget build(BuildContext context) {
    final interval = setup.firstBeepInterval.inMilliseconds / 1000;
    final minutes = setup.maxDuration.inSeconds / 60;
    return Row(
      children: [
        _Stat(
          icon: Icons.volume_up,
          value: '${formatDecimal(interval)} s',
          label: 'entre 2 bips',
        ),
        const SizedBox(width: 10),
        _Stat(
          icon: Icons.stairs,
          value: '${setup.stageCount}',
          label: 'paliers',
        ),
        const SizedBox(width: 10),
        _Stat(
          icon: Icons.timer,
          value: '${formatDecimal(minutes)} min',
          label: 'durée max',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.onPrimaryContainer),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
