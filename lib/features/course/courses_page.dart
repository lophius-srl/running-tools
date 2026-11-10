import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_repository.dart';
import '../../data/providers.dart';
import '../../domain/course_profile.dart';
import '../common/gpx_picker.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'course_detail_page.dart';
import 'course_text.dart';

/// Parcours importés ; import d'un GPX.
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  var _courses = <SavedCourse>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(courseRepositoryProvider.future);
    final courses = await repo.all();
    if (mounted) setState(() => _courses = courses);
  }

  Future<void> _import() async {
    final picked = await ref.read(gpxPickerProvider)();
    if (picked == null || !mounted) return;
    try {
      final course = SavedCourse(
        id: 'course-${DateTime.now().microsecondsSinceEpoch}',
        profile: parseGpxCourse(picked.content, fallbackName: picked.name),
      );
      final repo = await ref.read(courseRepositoryProvider.future);
      await repo.save(course);
      await _load();
      if (mounted) await _open(course);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _open(SavedCourse course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CourseDetailPage(course: course)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const RunHeader(entry: HomeEntry.simulator),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Importe le GPX de ta course (site de l’organisateur, '
                'Strava, Garmin…) : profil, sections et allure cible selon '
                'le relief.',
              ),
              const SizedBox(height: 12),
              for (final c in _courses)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.terrain),
                    title: Text(c.profile.name),
                    subtitle: Text(
                      '${formatKm(c.profile.distanceM)} · '
                      'D+ ${c.profile.climb().gain.round()} m',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(c),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.file_open),
                label: const Text('Importer un GPX'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
