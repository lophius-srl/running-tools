import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/marker_spacing.dart';
import '../../domain/measurement_method.dart';
import '../../domain/shoe_measure.dart';
import '../common/decimal_text.dart';

enum _Direction { spacingToSteps, stepsToSpacing }

/// Mesure des repères au pas talon-pointe.
class ShoeSection extends ConsumerStatefulWidget {
  const ShoeSection({super.key, required this.onChosen});

  final ValueChanged<SpacingChoice> onChosen;

  @override
  ConsumerState<ShoeSection> createState() => _ShoeSectionState();
}

class _ShoeSectionState extends ConsumerState<ShoeSection> {
  final _lengthCm = TextEditingController();
  final _calibrationDistance = TextEditingController(text: '10');
  final _calibrationSteps = TextEditingController();
  final _spacing = TextEditingController(text: '20');
  final _steps = TextEditingController();
  var _direction = _Direction.spacingToSteps;
  var _calibrating = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLength();
  }

  Future<void> _loadSavedLength() async {
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    final saved = await prefs.shoeLengthM();
    if (saved != null && mounted && _lengthCm.text.isEmpty) {
      setState(() => _lengthCm.text = formatDecimal(saved * 100));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _lengthCm,
      _calibrationDistance,
      _calibrationSteps,
      _spacing,
      _steps,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ShoeMeasure? get _shoe {
    final cm = parseDecimal(_lengthCm.text);
    return cm != null && cm > 0 ? ShoeMeasure(cm / 100) : null;
  }

  void _applyCalibration() {
    final distance = parseDecimal(_calibrationDistance.text);
    final steps = parseDecimal(_calibrationSteps.text);
    if (distance == null || distance <= 0 || steps == null || steps <= 0) {
      return;
    }
    final shoe = ShoeMeasure.calibrated(distanceM: distance, steps: steps);
    setState(() {
      _lengthCm.text = formatDecimal(shoe.footLengthM * 100);
      _calibrating = false;
    });
  }

  /// Espacement retenu et phrase à afficher ; `null` si saisie incomplète.
  (double, String)? _result(ShoeMeasure shoe) {
    switch (_direction) {
      case _Direction.spacingToSteps:
        final spacing = parseDecimal(_spacing.text);
        if (spacing == null || spacing <= 0) return null;
        final r = shoe.stepsFor(spacing);
        final rest = r.remainderM > 0
            ? ' + ${formatDecimal(r.remainderM * 100)} cm'
            : '';
        return (spacing, 'Compte ${r.steps} pas$rest entre deux repères.');
      case _Direction.stepsToSpacing:
        final steps = parseDecimal(_steps.text);
        if (steps == null || steps <= 0) return null;
        final spacing = shoe.distanceFor(steps);
        return (
          spacing,
          'Tes repères sont espacés de ${formatDecimal(spacing)} m.',
        );
    }
  }

  Future<void> _validate(ShoeMeasure shoe, double spacing) async {
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    await prefs.setShoeLengthM(shoe.footLengthM);
    widget.onChosen(
      SpacingChoice(spacing, MeasurementMethod.shoe, source: 'Chaussure'),
    );
  }

  Widget _number(TextEditingController c, String label, String unit) =>
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

  @override
  Widget build(BuildContext context) {
    final shoe = _shoe;
    final result = shoe == null ? null : _result(shoe);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _number(_lengthCm, 'Longueur de la chaussure', 'cm'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _calibrating = !_calibrating),
            child: const Text('Je ne la connais pas : calibrer'),
          ),
        ),
        if (_calibrating) ...[
          const Text(
            'Mesure une distance connue (ex. 10 m au décamètre), puis compte '
            'tes pas talon-pointe dessus.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _number(_calibrationDistance, 'Distance', 'm')),
              const SizedBox(width: 8),
              Expanded(child: _number(_calibrationSteps, 'Pas', 'pas')),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _applyCalibration,
              child: const Text('Calculer la longueur'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SegmentedButton<_Direction>(
          segments: const [
            ButtonSegment(
              value: _Direction.spacingToSteps,
              label: Text('Mètres → pas'),
            ),
            ButtonSegment(
              value: _Direction.stepsToSpacing,
              label: Text('Pas → mètres'),
            ),
          ],
          selected: {_direction},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _direction = s.single),
        ),
        const SizedBox(height: 12),
        if (_direction == _Direction.spacingToSteps)
          _number(_spacing, 'Espacement voulu', 'm')
        else
          _number(_steps, 'Pas comptés', 'pas'),
        if (result != null) ...[
          const SizedBox(height: 12),
          Text(
            result.$2,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: shoe != null && result != null
              ? () => _validate(shoe, result.$1)
              : null,
          child: const Text('Utiliser cet espacement'),
        ),
      ],
    );
  }
}
