import 'dart:io';

import '../domain/course_profile.dart';
import 'json_file_store.dart';

/// Comment l'allure est fixée.
enum CoursePacing {
  target('Objectif de temps'),
  flatPace('Allure sur le plat');

  const CoursePacing(this.label);
  final String label;
}

/// Un parcours importé, avec son profil lissé et son réglage d'allure.
class SavedCourse {
  const SavedCourse({
    required this.id,
    required this.profile,
    this.pacing = CoursePacing.flatPace,
    this.value = const Duration(minutes: 5),
  });

  final String id;
  final CourseProfile profile;
  final CoursePacing pacing;

  /// Temps visé ou allure plat (par km), selon [pacing].
  final Duration value;

  SavedCourse copyWith({CoursePacing? pacing, Duration? value}) => SavedCourse(
    id: id,
    profile: profile,
    pacing: pacing ?? this.pacing,
    value: value ?? this.value,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': profile.name,
    'elevations': [for (final e in profile.elevations) (e * 10).round() / 10],
    'pacing': pacing.name,
    'valueS': value.inSeconds,
  };

  static SavedCourse? fromJson(Map<String, Object?> json) {
    try {
      return SavedCourse(
        id: json['id']! as String,
        profile: CourseProfile(
          name: json['name']! as String,
          elevations: [
            for (final e in json['elevations']! as List) (e as num).toDouble(),
          ],
        ),
        pacing: CoursePacing.values.byName(json['pacing']! as String),
        value: Duration(seconds: json['valueS']! as int),
      );
    } on Object {
      return null;
    }
  }
}

abstract interface class CourseRepository {
  /// Parcours, le plus récent en premier.
  Future<List<SavedCourse>> all();
  Future<void> save(SavedCourse course);
  Future<void> delete(String id);
}

class JsonCourseRepository implements CourseRepository {
  JsonCourseRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/courses.json'));

  final JsonFileStore _store;

  @override
  Future<List<SavedCourse>> all() async {
    final raw = (await _store.read())?['courses'];
    return raw is List
        ? [
            for (final c in raw)
              if (c is Map<String, Object?>) ?SavedCourse.fromJson(c),
          ]
        : [];
  }

  /// Ajoute, ou remplace celui de même id sans changer l'ordre.
  @override
  Future<void> save(SavedCourse course) async {
    final list = await all();
    final i = list.indexWhere((c) => c.id == course.id);
    if (i < 0) {
      list.insert(0, course);
    } else {
      list[i] = course;
    }
    await _write(list);
  }

  @override
  Future<void> delete(String id) async => _write([
    for (final c in await all())
      if (c.id != id) c,
  ]);

  Future<void> _write(List<SavedCourse> list) => _store.write({
    'version': 1,
    'courses': [for (final c in list) c.toJson()],
  });
}
