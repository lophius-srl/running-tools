import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/debrief/cardio_analysis.dart';

import '../../domain/debrief/clean_activity.dart';
import '../../domain/debrief/effort_track.dart';
import '../../domain/debrief/pacing_analysis.dart';
import '../../domain/debrief/session_type.dart';
import '../../domain/training_paces.dart';
import '../common/date_text.dart';
import '../common/run_widgets.dart';
import '../course/course_text.dart';
import '../home/home_entry.dart';
import 'analysis_sections.dart';
import 'debrief_text.dart';

/// Étape 1 du débrief : ce qui a été lu dans la sortie, et son type.
class ActivitySummaryPage extends ConsumerStatefulWidget {
  const ActivitySummaryPage({
    super.key,
    required this.activity,
    required this.detected,
    this.vmaKmh,
  });

  final CleanActivity activity;
  final SessionType detected;

  /// VMA du dernier test, `null` si aucun.
  final double? vmaKmh;

  @override
  ConsumerState<ActivitySummaryPage> createState() =>
      _ActivitySummaryPageState();
}

class _ActivitySummaryPageState extends ConsumerState<ActivitySummaryPage> {
  late var _type = widget.detected;
  late final _track = EffortTrack(widget.activity);
  late final _hills = hillReports(_track);
  late final _quality = assessHeartRate(widget.activity);
  late final _cadence = cadenceReport(widget.activity);
  late final List<ZoneTime>? _paceZones = widget.vmaKmh == null
      ? null
      : paceZoneTimes(_track, widget.vmaKmh!);
  int? _maxHr;

  bool get _useHeartRate => widget.activity.hasHeartRate && _quality.reliable;

  @override
  void initState() {
    super.initState();
    _loadMaxHeartRate();
  }

  /// FC max : la plus haute vue dans les sorties (FC fiable), modifiable.
  Future<void> _loadMaxHeartRate() async {
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    var stored = await prefs.maxHeartRate();
    final seen = _useHeartRate ? observedMaxHeartRate(widget.activity) : null;
    if (seen != null && (stored == null || seen > stored)) {
      await prefs.setMaxHeartRate(seen);
      stored = seen;
    }
    if (mounted) setState(() => _maxHr = stored);
  }

  Future<void> _editMaxHeartRate() async {
    final controller = TextEditingController(text: '${_maxHr ?? ''}');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FC max'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'bpm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.of(context)
                  .pop(v != null && v >= 120 && v <= 230 ? v : null);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final prefs = await ref.read(preferencesRepositoryProvider.future);
    await prefs.setMaxHeartRate(value);
    if (mounted) setState(() => _maxHr = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.activity;
    final pace = a.averageKmh <= 0
        ? '–'
        : '${formatPace(paceForSpeed(a.averageKmh))}/km';
    final climb = a.elevationChange();
    final pacing = PacingAnalysis.of(_track, _type);
    final vma = widget.vmaKmh == null
        ? null
        : compareToVma(_track, _type, widget.vmaKmh!);
    final drift = _useHeartRate ? cardiacDrift(_track, _type) : null;
    final hrZones = _useHeartRate && _maxHr != null
        ? heartRateZoneTimes(a, _maxHr!)
        : null;
    final mismatch = zoneMismatch(
      type: _type,
      heartRateZones: hrZones,
      paceZones: _paceZones,
    );
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    Widget stream(String label, bool present) => Chip(
      avatar: Icon(
        present ? Icons.check_circle : Icons.remove_circle_outline,
        color: present ? const Color(0xFF15803D) : theme.colorScheme.outline,
      ),
      label: Text(label),
    );
    return Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.debrief, trailing: a.name),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  formatDateTime(a.start.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                row('Distance', formatKm(a.distanceM, decimals: 2)),
                row('Temps en mouvement', formatRaceTime(a.movingS)),
                row(
                  'Temps total',
                  formatRaceTime(a.elapsed.inSeconds.toDouble()),
                ),
                row('Allure moyenne', pace),
                if (climb != null)
                  row(
                    'Dénivelé',
                    '+${climb.gain.round()} m / −${climb.loss.round()} m',
                  ),
                const SizedBox(height: 16),
                Text('Type de séance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in SessionType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Détecté : ${widget.detected.label}. Corrige si besoin.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                KeyFindingsCard(
                  findings: keyFindings(
                    pacing: pacing,
                    hills: _hills,
                    vma: vma,
                    type: _type,
                    drift: drift,
                    zones: mismatch,
                    cadence: _cadence,
                  ),
                  gainable: gainableText(pacing.gainableS),
                  warning: a.hasHeartRate && !_quality.reliable
                      ? 'FC peu fiable sur cette sortie : pas de conclusion '
                            'cardio.'
                      : null,
                ),
                Text('Le détail', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                PacingTile(pacing: pacing, type: _type),
                if (a.hasElevation) HillsTile(hills: _hills),
                VmaTile(comparison: vma, vmaKmh: widget.vmaKmh, type: _type),
                if (a.hasHeartRate)
                  HeartTile(
                    quality: _quality,
                    driftText: driftLine(drift, _type, (
                      tooShort: a.movingS < 40 * 60,
                    )),
                  ),
                if (hrZones != null || _paceZones != null)
                  ZonesTile(
                    summary: mismatch != null
                        ? 'Trop intense pour une ${_type.label.toLowerCase()} : '
                              '${(mismatch.share * 100).round()} % du temps '
                              '${mismatch.byHeartRate ? 'en zone 3 ou plus' : 'au-dessus de 80 % de ta VMA'}.'
                        : _type == SessionType.endurance ||
                              _type == SessionType.long
                        ? 'Intensité conforme à une ${_type.label.toLowerCase()}.'
                        : 'Répartition de ton temps par intensité.',
                    heartRateZones: hrZones,
                    paceZones: _paceZones,
                    maxHeartRate: _useHeartRate ? _maxHr : null,
                    onEditMaxHeartRate: _editMaxHeartRate,
                  ),
                if (_cadence case final c?) CadenceTile(report: c),
                AnalysisTile(
                  title: 'Données de la sortie',
                  summary: a.pauses.isEmpty
                      ? 'Aucune pause retirée.'
                      : '${a.pauses.length} pause${a.pauses.length > 1 ? 's' : ''} '
                            'retirée${a.pauses.length > 1 ? 's' : ''} '
                            '(${spokenDuration(a.pausedTime.inSeconds.toDouble())}).',
                  children: [
                    for (final p in a.pauses)
                      Text(
                        'Arrêt au km '
                        '${(p.atM / 1000).toStringAsFixed(1).replaceAll('.', ',')}'
                        ' : ${spokenDuration(p.duration.inSeconds.toDouble())}',
                      ),
                    if (a.pauses.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Seuls les vrais arrêts (immobile plus de 20 s, ou '
                          'montre en pause) sont retirés ; la marche compte.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        stream('Altitude', a.hasElevation),
                        stream('Fréquence cardiaque', a.hasHeartRate),
                        stream('Cadence', a.hasCadence),
                      ],
                    ),
                    if (!a.hasHeartRate || !a.hasCadence)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Les analyses qui en dépendent seront masquées.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (a.rejectedFixes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${a.rejectedFixes} points GPS aberrants écartés.',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Indications d’entraînement, pas un avis médical.',
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
