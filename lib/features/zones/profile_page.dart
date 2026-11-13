import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_repository.dart';
import '../../data/providers.dart';
import '../../domain/zones/zone_inputs.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'zone_profile.dart';

/// Mon profil : les trois données qui font mes zones.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String unit,
    required String? current,
    required Future<void> Function(String? text) save,
    String? help,
  }) async {
    final result = await showDialog<({String? text})>(
      context: context,
      builder: (_) =>
          _ValueDialog(title: title, unit: unit, current: current, help: help),
    );
    if (result == null) return;
    await save(result.text);
    ref.invalidate(zoneProfileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(zoneProfileProvider).value;
    final now = DateTime.now();
    Future<void> repo(Future<void> Function(ProfileRepository r) f) async =>
        f(await ref.read(profileRepositoryProvider.future));

    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.profile),
          Expanded(
            child: profile == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InputCard(
                        title: 'VMA',
                        value: profile.vma == null
                            ? '–'
                            : '${formatDecimal(profile.vma!.value)} km/h',
                        input: profile.vma,
                        reminder: vmaReminder(profile.vma, now),
                        onEdit: () => _edit(
                          context,
                          ref,
                          title: 'VMA',
                          unit: 'km/h',
                          current: profile.data.manualVma == null
                              ? null
                              : formatDecimal(profile.data.manualVma!.value),
                          help:
                              'Un nouveau test de VMA remplacera cette saisie.',
                          save: (t) => repo(
                            (r) => r.setManualVma(
                              t == null ? null : parseDecimal(t),
                            ),
                          ),
                        ),
                      ),
                      _InputCard(
                        title: 'FC max',
                        value: profile.maxHeartRate == null
                            ? '–'
                            : '${profile.maxHeartRate!.value} bpm',
                        input: profile.maxHeartRate,
                        reminder: maxHeartRateReminder(profile.maxHeartRate),
                        onEdit: () => _edit(
                          context,
                          ref,
                          title: 'FC max',
                          unit: 'bpm',
                          current: profile.data.manualMaxHeartRate?.value
                              .toString(),
                          help:
                              'La plus haute vraiment mesurée : fin de VAMEVAL, '
                              'côte à fond.',
                          save: (t) => repo(
                            (r) => r.setManualMaxHeartRate(
                              t == null ? null : _bpm(t, 120, 230),
                            ),
                          ),
                        ),
                      ),
                      _InputCard(
                        title: 'FC de repos',
                        value: profile.restHeartRate == null
                            ? '–'
                            : '${profile.restHeartRate!.value} bpm',
                        input: profile.restHeartRate,
                        reminder: restHeartRateReminder(
                          profile.restHeartRate,
                          now,
                        ),
                        onEdit: () => _edit(
                          context,
                          ref,
                          title: 'FC de repos',
                          unit: 'bpm',
                          current: profile.data.manualRestHeartRate?.value
                              .toString(),
                          help:
                              'Un nouveau test orthostatique remplacera cette '
                              'saisie.',
                          save: (t) => repo(
                            (r) => r.setManualRestHeartRate(
                              t == null ? null : _bpm(t, 30, 110),
                            ),
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Année de naissance'),
                          subtitle: const Text(
                            'Sert seulement à estimer ta FC max (220 − âge) '
                            'si tu n’en as pas mesuré.',
                          ),
                          trailing: Text(
                            '${profile.data.birthYear ?? '–'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          onTap: () => _edit(
                            context,
                            ref,
                            title: 'Année de naissance',
                            unit: '',
                            current: profile.data.birthYear?.toString(),
                            save: (t) => repo(
                              (r) => r.setBirthYear(
                                t == null ? null : _bpm(t, 1920, now.year - 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Repères d’entraînement, pas un avis médical.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Entier dans [min, max], sinon `null` (saisie effacée).
  static int? _bpm(String text, int min, int max) {
    final v = int.tryParse(text);
    return v != null && v >= min && v <= max ? v : null;
  }
}

/// Saisie d'une valeur ; le champ vit et meurt avec la fenêtre.
class _ValueDialog extends StatefulWidget {
  const _ValueDialog({
    required this.title,
    required this.unit,
    required this.current,
    this.help,
  });

  final String title;
  final String unit;
  final String? current;
  final String? help;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final _controller = TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile-value'),
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: widget.unit),
        ),
        if (widget.help case final help?) ...[
          const SizedBox(height: 8),
          Text(help, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop((text: null)),
        child: const Text('Valeur automatique'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop((text: _controller.text.trim())),
        child: const Text('OK'),
      ),
    ],
  );
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.value,
    required this.input,
    required this.reminder,
    required this.onEdit,
  });

  final String title;
  final String value;
  final ProfileValue<num>? input;
  final String? reminder;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = input;
    final source = i == null
        ? 'Pas encore de valeur'
        : [
            'Source : ${i.source.label}',
            if (i.detail != null) i.detail!,
            if (i.count != null) '${i.count} mesure${i.count! > 1 ? 's' : ''}',
            if (i.date != null)
              formatDateTime(i.date!.toLocal()).split(',').first,
          ].join(' · ');
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(onPressed: onEdit, child: const Text('Modifier')),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(source, style: theme.textTheme.bodySmall),
            if (reminder case final r?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
