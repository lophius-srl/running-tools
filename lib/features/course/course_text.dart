import '../../data/course_repository.dart';
import '../../domain/course_profile.dart';
import '../../domain/grade_pace.dart';
import '../../domain/training_paces.dart';

/// « 25:00 » ou « 1:52:10 ».
String formatRaceTime(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// « 12,3 km ».
String formatKm(double meters, {int decimals = 1}) =>
    '${(meters / 1000).toStringAsFixed(decimals).replaceAll('.', ',')} km';

/// Bande d'allure à partager ou recopier sur un bracelet.
String paceBandText(SavedCourse course, CoursePlan plan) {
  final climb = course.profile.climb();
  final lines = [
    course.profile.name,
    '${formatKm(course.profile.distanceM)} · D+ ${climb.gain.round()} m · '
        'D− ${climb.loss.round()} m',
    'Objectif ${formatRaceTime(plan.totalS)} '
        '(allure plat ${formatPace(plan.flatPace)}/km)',
    '',
    'Sections :',
    for (final p in plan.paced)
      '${p.section.kind.label} ${formatKm(p.section.startM)} → '
          '${formatKm(p.section.endM)} : ${formatPace(p.pace)}/km, '
          'passage ${formatRaceTime(p.splitS)}',
    '',
    'Passages :',
    for (final (km, split) in plan.paceBand)
      '${km == km.roundToDouble() ? '${km.round()} km' : formatKm(km * 1000, decimals: 2)}'
          ' : ${formatRaceTime(split)}',
  ];
  return lines.join('\n');
}

/// Plan d'allures selon le réglage du parcours.
CoursePlan planOf(SavedCourse course, List<CourseSection> sections) =>
    course.pacing == CoursePacing.target
    ? CoursePlan.fromTarget(course.profile, sections, course.value)
    : CoursePlan.fromFlatPace(course.profile, sections, course.value);
