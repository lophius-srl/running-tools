import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/debrief/cardio_analysis.dart';

import '../../domain/course_profile.dart';
import '../../domain/debrief/clean_activity.dart';
import '../../domain/debrief/debrief_score.dart';
import '../../domain/debrief/debrief_series.dart';
import '../../domain/debrief/debrief_summary.dart';
import '../../domain/debrief/effort_track.dart';
import '../../domain/debrief/pacing_analysis.dart';
import '../../domain/debrief/session_type.dart';
import '../../domain/training_paces.dart';
import '../common/date_text.dart';
import '../common/run_widgets.dart';
import '../course/course_text.dart';
import '../home/home_entry.dart';
import 'analysis_sections.dart';
import 'debrief_chart.dart';
import 'debrief_text.dart';

/// Le débrief d'une sortie : note, conseils, graphique, détail.
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
    await _save();
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
    await _save();
  }

  /// Tout ce que calcule le débrief, pour l'écran et l'historique.
  _Analysis _analyze() {
    final a = widget.activity;
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
    final findings = keyFindings(
      pacing: pacing,
      hills: _hills,
      vma: vma,
      type: _type,
      drift: drift,
      zones: mismatch,
      cadence: _cadence,
    );
    final score = debriefScore(
      pacing: pacing,
      hills: _hills,
      type: _type,
      movingS: a.movingS,
      zones: mismatch,
      drift: drift,
      cadence: _cadence,
    );
    return (
      pacing: pacing,
      vma: vma,
      drift: drift,
      hrZones: hrZones,
      mismatch: mismatch,
      findings: findings,
      score: score,
    );
  }

  /// Moments clés à marquer sur le graphique.
  List<ChartMarker> _markers(_Analysis x) => [
    if (_type != SessionType.interval && (x.pacing.fastStartPercent ?? 0) > 5)
      (km: 1.5, label: 'Départ rapide'),
    for (final h in _hills)
      if (h.section.kind == SectionKind.climb &&
          h.lostS < -15 &&
          (h.afterSlowdownS ?? 0) > 10)
        (km: h.section.startM / 1000, label: 'Côte coûteuse'),
    if (x.drift case final d? when d.significant)
      (
        km:
            _track.distanceAtTime(d.fromS + (_track.timeS - d.fromS) / 2) /
            1000,
        label: 'Dérive',
      ),
  ];

  /// Garde le résumé dans l'historique (même id pour la même sortie).
  Future<void> _save() async {
    final a = widget.activity;
    final x = _analyze();
    double? meanHr() {
      final hrs = [for (final p in a.points) ?p.heartRate];
      return hrs.isEmpty || !_useHeartRate
          ? null
          : hrs.reduce((s, h) => s + h) / hrs.length;
    }

    final repo = await ref.read(debriefRepositoryProvider.future);
    await repo.save(
      DebriefSummary(
        id: 'debrief-${a.start.millisecondsSinceEpoch}',
        date: a.start,
        name: a.name,
        type: _type,
        distanceM: a.distanceM,
        movingS: a.movingS,
        score: x.score.value,
        findings: [for (final f in x.findings) f.text],
        gainableS: x.pacing.gainableS,
        gapPaceS: x.pacing.averageGapPaceS,
        elevationGainM: a.elevationChange()?.gain,
        averageHeartRate: meanHr(),
        driftPercent: x.drift?.percent,
        averageCadence: _cadence?.average,
        vmaPercent: x.vma?.percent,
        start: a.startPosition,
      ),
    );
  }

  void _setType(SessionType type) {
    setState(() => _type = type);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.activity;
    final x = _analyze();
    final pace = a.averageKmh <= 0
        ? '–'
        : '${formatPace(paceForSpeed(a.averageKmh))}/km';
    final climb = a.elevationChange();
    final zonesSummary = switch (x.mismatch) {
      final m? =>
        'Trop intense pour une ${_type.label.toLowerCase()} : '
            '${(m.share * 100).round()} % du temps '
            '${m.byHeartRate ? 'en zone 3 ou plus' : 'au-dessus de 80 % de ta VMA'}.',
      null when _type == SessionType.endurance || _type == SessionType.long =>
        'Intensité conforme à une ${_type.label.toLowerCase()}.',
      null => 'Répartition de ton temps par intensité.',
    };
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
                ScoreCard(
                  score: x.score,
                  gainable: gainableText(x.pacing.gainableS),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in SessionType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => _setType(t),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Type détecté : ${widget.detected.label}. Corrige si besoin.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                KeyFindingsCard(
                  findings: x.findings,
                  gainable: null,
                  warning: a.hasHeartRate && !_quality.reliable
                      ? 'FC peu fiable sur cette sortie : pas de conclusion '
                            'cardio.'
                      : null,
                ),
                DebriefChart(
                  series: debriefSeries(_track),
                  markers: _markers(x),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, value) in [
                      ('Distance', formatKm(a.distanceM, decimals: 2)),
                      ('En mouvement', formatRaceTime(a.movingS)),
                      ('Allure', pace),
                      if (climb != null)
                        (
                          'Dénivelé',
                          '+${climb.gain.round()} / −${climb.loss.round()} m',
                        ),
                    ])
                      _Stat(label: label, value: value),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Le détail', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                PacingTile(pacing: x.pacing, type: _type),
                if (a.hasElevation) HillsTile(hills: _hills),
                VmaTile(comparison: x.vma, vmaKmh: widget.vmaKmh, type: _type),
                if (a.hasHeartRate)
                  HeartTile(
                    quality: _quality,
                    driftText: driftLine(x.drift, _type, (
                      tooShort: a.movingS < 40 * 60,
                    )),
                  ),
                if (x.hrZones != null || _paceZones != null)
                  ZonesTile(
                    summary: zonesSummary,
                    heartRateZones: x.hrZones,
                    paceZones: _paceZones,
                    maxHeartRate: _useHeartRate ? _maxHr : null,
                    onEditMaxHeartRate: _editMaxHeartRate,
                  ),
                if (_cadence case final c?) CadenceTile(report: c),
                ScoreTile(score: x.score),
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
                    Text(
                      'Temps total, pauses comprises : '
                      '${formatRaceTime(a.elapsed.inSeconds.toDouble())}',
                    ),
                    const SizedBox(height: 4),
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
                  'Indications d’entraînement, pas un avis médical. Le débrief '
                  'est gardé dans ton historique (résumé, sans le parcours).',
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

typedef _Analysis = ({
  PacingAnalysis pacing,
  VmaComparison? vma,
  CardiacDrift? drift,
  List<ZoneTime>? hrZones,
  ({double share, bool byHeartRate})? mismatch,
  List<Finding> findings,
  DebriefScore score,
});

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
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
  }
}
