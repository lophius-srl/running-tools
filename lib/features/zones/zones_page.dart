import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/zones/zones.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'profile_page.dart';
import 'zone_badge.dart';
import 'zone_profile.dart';

/// « 7,1–8,9 km/h ».
String speedRange(Zone z) {
  String f(double v) => formatDecimal(double.parse(v.toStringAsFixed(1)));
  if (z.maxKmh == null) return '–';
  return z.minKmh == null
      ? '< ${f(z.maxKmh!)}'
      : '${f(z.minKmh!)}–${f(z.maxKmh!)}';
}

/// Mes zones : allure, vitesse et FC de Z1 à Z5.
class ZonesPage extends ConsumerStatefulWidget {
  const ZonesPage({super.key});

  @override
  ConsumerState<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends ConsumerState<ZonesPage> {
  @override
  void initState() {
    super.initState();
    _markSeen();
  }

  /// Ouvrir Mes zones vaut « vu » pour l'alerte de changement.
  Future<void> _markSeen() async {
    await ref.read(zoneProfileProvider.future);
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.markVersionsSeen();
  }

  Future<void> _editBounds(ZoneProfile profile, ZoneId id) async {
    final i = id.index;
    final s = profile.data.settings;
    final values = await showDialog<_BoundValues>(
      context: context,
      builder: (_) => _BoundsDialog(
        title: 'Fin de ${id.short} (${id.label})',
        pace: formatDecimal(s.paceUpper[i]),
        heartRatePercent: formatDecimal(s.heartRateUpper[i]),
        heartRateBpm: s.heartRateUpperBpm[i]?.toString() ?? '',
      ),
    );
    if (values == null) return;
    var next = s;
    if (parseDecimal(values.pace) case final p?) {
      next = next.withPaceUpper(i, p);
    }
    if (parseDecimal(values.heartRatePercent) case final h?) {
      next = next.withHeartRateUpper(i, h);
    }
    if (int.tryParse(values.heartRateBpm.trim()) case final b?) {
      next = next.withHeartRateUpperBpm(i, b);
    }
    if (!next.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bornes incohérentes : chaque zone doit finir '
              'après la précédente.',
            ),
          ),
        );
      }
      return;
    }
    await _saveSettings(next);
  }

  Future<void> _saveSettings(ZoneSettings settings) async {
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.setSettings(settings);
    ref.invalidate(zoneProfileProvider);
    await ref.read(zoneProfileProvider.future);
    await repo.markVersionsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(zoneProfileProvider).value;
    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.zones),
          Expanded(
            child: profile == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Inputs(profile: profile),
                      const SizedBox(height: 12),
                      for (final z in profile.zones.zones)
                        _ZoneCard(
                          zone: z,
                          onTap: () => _editBounds(profile, z.id),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Allure pour les efforts courts (moins de 3 min) ; FC '
                        'pour les efforts longs, les côtes et la chaleur.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Touche une zone pour ajuster sa fin (en % ou en bpm). '
                        'Tes ajustements restent même quand ta VMA ou ta FC '
                        'changent.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (!profile.data.settings.isDefault)
                        TextButton.icon(
                          onPressed: () => _saveSettings(const ZoneSettings()),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Valeurs par défaut'),
                        ),
                      if (profile.versions.length > 1) ...[
                        const SizedBox(height: 16),
                        Text('Historique', style: theme.textTheme.titleMedium),
                        for (var i = profile.versions.length - 1; i > 0; i--)
                          _VersionTile(
                            date: profile.versions[i].date,
                            changes: diffZones(
                              profile.versions[i - 1].zones,
                              profile.versions[i].zones,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Repères d’entraînement, pas un avis médical.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

typedef _BoundValues = ({
  String pace,
  String heartRatePercent,
  String heartRateBpm,
});

/// Fin d'une zone, en % de VMA, en % de FC de réserve ou en bpm.
class _BoundsDialog extends StatefulWidget {
  const _BoundsDialog({
    required this.title,
    required this.pace,
    required this.heartRatePercent,
    required this.heartRateBpm,
  });

  final String title;
  final String pace;
  final String heartRatePercent;
  final String heartRateBpm;

  @override
  State<_BoundsDialog> createState() => _BoundsDialogState();
}

class _BoundsDialogState extends State<_BoundsDialog> {
  late final _pace = TextEditingController(text: widget.pace);
  late final _hrPct = TextEditingController(text: widget.heartRatePercent);
  late final _hrBpm = TextEditingController(text: widget.heartRateBpm);

  @override
  void dispose() {
    _pace.dispose();
    _hrPct.dispose();
    _hrBpm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('bound-pace'),
            controller: _pace,
            keyboardType: decimal,
            decoration: const InputDecoration(
              labelText: 'Allure',
              suffixText: '% VMA',
            ),
          ),
          TextField(
            key: const Key('bound-hr-pct'),
            controller: _hrPct,
            keyboardType: decimal,
            decoration: const InputDecoration(
              labelText: 'FC',
              suffixText: '% FC de réserve',
            ),
          ),
          TextField(
            key: const Key('bound-hr-bpm'),
            controller: _hrBpm,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ou FC fixe (prioritaire)',
              suffixText: 'bpm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            pace: _pace.text,
            heartRatePercent: _hrPct.text,
            heartRateBpm: _hrBpm.text,
          )),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _Inputs extends StatelessWidget {
  const _Inputs({required this.profile});

  final ZoneProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String detail(DateTime? d, String source) => [
      source,
      if (d != null) formatDateTime(d.toLocal()).split(',').first,
    ].join(' · ');
    final items = [
      (
        'VMA',
        profile.vma == null ? '–' : '${formatDecimal(profile.vma!.value)} km/h',
        profile.vma == null
            ? 'à mesurer'
            : detail(profile.vma!.date, profile.vma!.source.label),
      ),
      (
        'FC max',
        profile.maxHeartRate == null ? '–' : '${profile.maxHeartRate!.value}',
        profile.maxHeartRate?.source.label ?? 'à saisir',
      ),
      (
        'FC repos',
        profile.restHeartRate == null ? '–' : '${profile.restHeartRate!.value}',
        profile.restHeartRate == null
            ? 'à mesurer'
            : detail(
                profile.restHeartRate!.date,
                profile.restHeartRate!.source.label,
              ),
      ),
    ];
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ProfilePage())),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value, source) in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.labelMedium),
                        Text(
                          value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          source,
                          maxLines: 3,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.onTap});

  final Zone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = zoneColor(zone.id);
    final pace = paceRange(zone);
    final bpm = bpmRange(zone);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 8, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            zone.id.short,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              zone.id.label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      Text(zone.id.usage, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _Figure(
                              label: 'Allure',
                              value: pace == null ? '–' : '$pace/km',
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _Figure(
                              label: 'km/h',
                              value: zone.hasPace ? speedRange(zone) : '–',
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _Figure(
                              label: 'FC (bpm)',
                              value: bpm ?? '–',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.date, required this.changes});

  final DateTime date;
  final List<ZoneChange> changes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDateTime(date.toLocal()),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        for (final c in changes) Text(c.text),
      ],
    ),
  );
}
