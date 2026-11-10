import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_repository.dart';
import '../../data/providers.dart';
import '../../device/share_service.dart';
import '../../domain/course_profile.dart';
import '../../domain/grade_pace.dart';
import '../../domain/training_paces.dart';
import '../checklists/new_race_page.dart';
import '../checklists/race_checklist_page.dart';
import '../common/duration_text.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'course_text.dart';

/// Profil, réglage d'allure, sections et bande d'allure d'un parcours.
class CourseDetailPage extends ConsumerStatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final SavedCourse course;

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  late SavedCourse _course = widget.course;
  late final List<CourseSection> _sections = splitSections(_course.profile);
  late final _value = TextEditingController(text: _valueText(_course));

  static String _valueText(SavedCourse c) => c.pacing == CoursePacing.target
      ? formatRaceTime(c.value.inSeconds.toDouble())
      : formatPace(c.value);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save(SavedCourse course) async {
    setState(() => _course = course);
    final repo = await ref.read(courseRepositoryProvider.future);
    await repo.save(course);
  }

  void _onValueChanged(String text) {
    final value = parseClock(text);
    final min = _course.pacing == CoursePacing.target
        ? const Duration(minutes: 1)
        : const Duration(minutes: 2);
    if (value == null || value < min) {
      setState(() {});
      return;
    }
    _save(_course.copyWith(value: value));
  }

  void _onPacingChanged(CoursePacing pacing) {
    // On garde le même plan : le temps prévu devient l'objectif, ou
    // l'allure plat devient la base.
    final plan = planOf(_course, _sections);
    final value = pacing == CoursePacing.target
        ? Duration(seconds: plan.totalS.round())
        : plan.flatPace;
    final course = _course.copyWith(pacing: pacing, value: value);
    _value.text = _valueText(course);
    _save(course);
  }

  Future<void> _openChecklist() async {
    final checklists = await ref.read(checklistRepositoryProvider.future);
    final race = (await checklists.races())
        .where((r) => r.courseId == _course.id)
        .firstOrNull;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => race != null
            ? RaceChecklistPage(checklistId: race.id)
            : NewRacePage(
                courseId: _course.id,
                initialName: _course.profile.name,
              ),
      ),
    );
  }

  Future<void> _delete() async {
    final repo = await ref.read(courseRepositoryProvider.future);
    await repo.delete(_course.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _course.profile;
    final climb = profile.climb();
    final valid = parseClock(_value.text) != null;
    final plan = planOf(_course, _sections);
    final target = _course.pacing == CoursePacing.target;
    return Scaffold(
      body: Column(
        children: [
          RunHeader(entry: HomeEntry.simulator, trailing: profile.name),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${formatKm(profile.distanceM)} · D+ ${climb.gain.round()} m'
                  ' · D− ${climb.loss.round()} m',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ProfileChart(profile: profile, sections: _sections),
                ),
                const SizedBox(height: 16),
                SegmentedButton<CoursePacing>(
                  segments: [
                    for (final p in CoursePacing.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_course.pacing},
                  onSelectionChanged: (s) => _onPacingChanged(s.single),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('course-value'),
                  controller: _value,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: target ? 'Temps visé' : 'Allure sur le plat',
                    hintText: target ? '1:45:00' : '5:00',
                    suffixText: target ? null : '/km',
                    errorText: valid ? null : 'Format min:ss ou h:mm:ss',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onValueChanged,
                ),
                const SizedBox(height: 12),
                Text(
                  target
                      ? 'Allure sur le plat : ${formatPace(plan.flatPace)}/km'
                      : 'Temps prévu : ${formatRaceTime(plan.totalS)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Sections', style: theme.textTheme.titleMedium),
                for (final p in plan.paced) _SectionTile(paced: p),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Passages au km',
                    style: theme.textTheme.titleMedium,
                  ),
                  children: [
                    for (final (km, split) in plan.paceBand)
                      ListTile(
                        dense: true,
                        title: Text(
                          km == km.roundToDouble()
                              ? '${km.round()} km'
                              : formatKm(km * 1000, decimals: 2),
                        ),
                        trailing: Text(
                          formatRaceTime(split),
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref
                      .read(shareServiceProvider)
                      .shareText(
                        paceBandText(_course, plan),
                        subject: profile.name,
                      ),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Partager la bande d’allure'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openChecklist,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Checklist de la course'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer ce parcours'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Couleur d'une section, partagée par le profil et le tableau.
Color sectionColor(SectionKind kind, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (kind) {
    SectionKind.climb =>
      dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    SectionKind.descent =>
      dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
    SectionKind.flat =>
      dark ? const Color(0xFF6EA0FF) : const Color(0xFF1E63E9),
  };
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.paced});

  final PacedSection paced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = paced.section;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (s.kind) {
        SectionKind.climb => Icons.north_east,
        SectionKind.descent => Icons.south_east,
        SectionKind.flat => Icons.east,
      }, color: sectionColor(s.kind, theme.brightness)),
      title: Text(
        '${s.kind.label} · ${formatKm(s.startM)} → ${formatKm(s.endM)}',
      ),
      subtitle: Text(
        '+${paced.gain.round()} m / −${paced.loss.round()} m · '
        'passage ${formatRaceTime(paced.splitS)}',
      ),
      trailing: Text(
        '${formatPace(paced.pace)}/km',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Altitude selon la distance, colorée par section.
class ProfileChart extends StatelessWidget {
  const ProfileChart({
    super.key,
    required this.profile,
    required this.sections,
  });

  final CourseProfile profile;
  final List<CourseSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = profile.elevations;
    final low = e.reduce(min), high = e.reduce(max);
    final pad = max(10.0, (high - low) * 0.1);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // Un point tous les 50 m suffit à l'écran.
    final stride = max(1, e.length ~/ 400);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: profile.distanceM / 1000,
        minY: (low - pad).floorToDouble(),
        maxY: (high + pad).ceilToDouble(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.round()} m', style: muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: max(1, (profile.distanceM / 1000 / 5).ceilToDouble()),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.round()} km', style: muted),
              ),
            ),
          ),
        ),
        lineBarsData: [
          for (final s in sections)
            LineChartBarData(
              spots: [
                for (var i = s.from; i <= s.to; i += stride)
                  FlSpot(i * CourseProfile.stepM / 1000, e[i]),
                FlSpot(s.endM / 1000, e[s.to]),
              ],
              color: sectionColor(s.kind, theme.brightness),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: sectionColor(
                  s.kind,
                  theme.brightness,
                ).withValues(alpha: 0.15),
              ),
            ),
        ],
      ),
    );
  }
}
