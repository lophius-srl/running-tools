import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/marker_spacing.dart';
import '../domain/measurement_method.dart';
import '../features/common/decimal_text.dart';
import 'ar_measure_page.dart';

/// Outil de mesure des repères ; renvoie l'espacement retenu, ou `null` si
/// l'utilisateur abandonne.
abstract interface class DistanceMeasurer {
  Future<SpacingChoice?> measure(
    BuildContext context, {
    required double initialSpacingM,
  });
}

/// Mesure en réalité augmentée (ARKit).
class ArKitDistanceMeasurer implements DistanceMeasurer {
  @override
  Future<SpacingChoice?> measure(
    BuildContext context, {
    required double initialSpacingM,
  }) => Navigator.of(context).push<SpacingChoice>(
    MaterialPageRoute(
      builder: (_) => ArMeasurePage(initialSpacingM: initialSpacingM),
    ),
  );
}

/// Saisie d'une distance mesurée par un autre moyen.
class ManualDistanceMeasurer implements DistanceMeasurer {
  const ManualDistanceMeasurer({this.message});

  /// Explication affichée en tête (ex. AR indisponible).
  final String? message;

  @override
  Future<SpacingChoice?> measure(
    BuildContext context, {
    required double initialSpacingM,
  }) => showDialog<SpacingChoice>(
    context: context,
    builder: (_) =>
        _ManualDialog(initialSpacingM: initialSpacingM, message: message),
  );
}

/// ARKit si l'appareil le permet, sinon saisie manuelle.
class AdaptiveDistanceMeasurer implements DistanceMeasurer {
  AdaptiveDistanceMeasurer({Future<bool> Function()? isArSupported})
    : _isArSupported =
          isArSupported ??
          (() =>
              ARKitPlugin.checkConfiguration(ARKitConfiguration.worldTracking));

  final Future<bool> Function() _isArSupported;

  @override
  Future<SpacingChoice?> measure(
    BuildContext context, {
    required double initialSpacingM,
  }) async {
    bool supported;
    try {
      supported = await _isArSupported();
    } on Object {
      // Vérification impossible : on se rabat sur la saisie manuelle.
      supported = false;
    }
    if (!context.mounted) return null;
    final DistanceMeasurer measurer = supported
        ? ArKitDistanceMeasurer()
        : const ManualDistanceMeasurer(
            message:
                'La réalité augmentée n’est pas disponible sur cet appareil. '
                'Saisis la distance mesurée.',
          );
    return measurer.measure(context, initialSpacingM: initialSpacingM);
  }
}

final distanceMeasurerProvider = Provider<DistanceMeasurer>(
  (ref) => AdaptiveDistanceMeasurer(),
);

class _ManualDialog extends StatefulWidget {
  const _ManualDialog({required this.initialSpacingM, this.message});

  final double initialSpacingM;
  final String? message;

  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  late final _distance = TextEditingController(
    text: formatDecimal(widget.initialSpacingM),
  );

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = parseDecimal(_distance.text);
    return AlertDialog(
      title: const Text('Distance mesurée'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message case final message?) ...[
            Text(message),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _distance,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Espacement',
              suffixText: 'm',
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
          onPressed: value != null && value > 0
              ? () =>
                    Navigator.of(context)
                        .pop(SpacingChoice(value, MeasurementMethod.manual))
              : null,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
