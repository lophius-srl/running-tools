import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../device/reminder_scheduler.dart';
import '../../domain/orthostatic.dart';
import '../common/date_text.dart';
import 'orthostatic_run_page.dart';

/// Identifiant fixe du rappel hebdomadaire.
const orthostaticReminderId = 650001;
const orthostaticPayload = 'orthostatic';

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// Suivi du test orthostatique : dernier résultat, historique, rappel.
class OrthostaticPage extends ConsumerStatefulWidget {
  const OrthostaticPage({super.key});

  @override
  ConsumerState<OrthostaticPage> createState() => _OrthostaticPageState();
}

class _OrthostaticPageState extends ConsumerState<OrthostaticPage> {
  var _results = <OrthostaticResult>[];
  ({int weekday, int hour, int minute})? _reminder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(orthostaticRepositoryProvider.future);
    final results = await repo.all();
    final reminder = await repo.reminder();
    if (mounted) {
      setState(() {
        _results = results;
        _reminder = reminder;
      });
    }
  }

  Future<void> _start() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const OrthostaticRunPage()));
    await _load();
  }

  Future<void> _editReminder() async {
    final current = _reminder;
    var weekday = current?.weekday ?? DateTime.monday;
    final day = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chaque semaine, le'),
        children: [
          for (var d = 1; d <= 7; d++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(d),
              child: Text(
                _weekdays[d - 1],
                style: const TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    weekday = day;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? 7,
        minute: current?.minute ?? 0,
      ),
      helpText: 'Au réveil, à',
    );
    if (time == null || !mounted) return;
    final value = (weekday: weekday, hour: time.hour, minute: time.minute);
    final scheduled = await ref
        .read(reminderSchedulerProvider)
        .scheduleWeekly(
          id: orthostaticReminderId,
          weekday: weekday,
          hour: time.hour,
          minute: time.minute,
          title: 'Test orthostatique',
          body: 'Avant de te lever : 5 minutes pour ton test de forme.',
          payload: orthostaticPayload,
        );
    if (!mounted) return;
    if (!scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications refusées : pas de rappel.'),
        ),
      );
      return;
    }
    final repo = await ref.read(orthostaticRepositoryProvider.future);
    await repo.setReminder(value);
    await _load();
  }

  Future<void> _removeReminder() async {
    await ref.read(reminderSchedulerProvider).cancel(orthostaticReminderId);
    final repo = await ref.read(orthostaticRepositoryProvider.future);
    await repo.setReminder(null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = _results.firstOrNull;
    final reminder = _reminder;
    return Scaffold(
      appBar: AppBar(title: const Text('Test orthostatique')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.favorite),
            label: const Text('Faire le test (5 min)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Indicateur de forme, pas un outil médical. Il compare tes '
                'mesures à TA moyenne, sans seuil absolu. En cas de doute ou '
                'de symptôme, consulte un médecin.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (latest != null)
            ResultCard(
              result: latest,
              status: OrthostaticBaseline.of(_results.skip(1).toList())
                  .statusOf(latest),
            )
          else
            const Text(
              'Fais le test au réveil, avant de te lever, idéalement le même '
              'jour chaque semaine.',
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(
              reminder == null
                  ? 'Pas de rappel hebdomadaire'
                  : 'Rappel le ${_weekdays[reminder.weekday - 1]} à '
                        '${reminder.hour}h${reminder.minute.toString().padLeft(2, '0')}',
            ),
            trailing: reminder == null
                ? TextButton(
                    onPressed: _editReminder,
                    child: const Text('Ajouter'),
                  )
                : IconButton(
                    tooltip: 'Retirer le rappel',
                    icon: const Icon(Icons.notifications_off_outlined),
                    onPressed: _removeReminder,
                  ),
            onTap: _editReminder,
          ),
          if (_results.length > 1) ...[
            const SizedBox(height: 8),
            Text('Historique', style: theme.textTheme.titleMedium),
            for (final (i, r) in _results.indexed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(formatDateTime(r.date)),
                subtitle: Text(
                  'Couché ${r.lyingBpm} · debout ${r.standingStableBpm} '
                  '(pic ${r.standingPeakBpm}) · ${r.source.label}',
                ),
                trailing: Text(
                  '+${r.delta}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color:
                        OrthostaticBaseline.of(_results.skip(i + 1).toList())
                                .statusOf(r) ==
                            FormStatus.watch
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Résultat d'un test et son statut par rapport à ma référence.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result, required this.status});

  final OrthostaticResult result;
  final FormStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      FormStatus.building => (
        'Référence en construction (3 tests)',
        theme.colorScheme.primary,
      ),
      FormStatus.normal => ('Dans ta normale', const Color(0xFF15803D)),
      FormStatus.watch => (
        'À surveiller : inhabituel pour toi',
        theme.colorScheme.error,
      ),
    };
    Widget figure(String title, int bpm) => Expanded(
      child: Column(
        children: [
          Text(
            '$bpm',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                figure('Couché', result.lyingBpm),
                figure('Debout', result.standingStableBpm),
                figure('Écart', result.delta),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pic au lever : ${result.standingPeakBpm} bpm'),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
