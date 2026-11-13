/// D'où vient une donnée du profil.
enum InputSource {
  test('dernier test'),
  manual('ta saisie'),
  observed('plus haute relevée dans tes sorties'),
  estimated('estimation 220 − âge'),
  orthostatic('test orthostatique');

  const InputSource(this.label);
  final String label;
}

/// Une donnée d'entrée des zones, avec sa provenance.
class ProfileValue<T extends num> {
  const ProfileValue({
    required this.value,
    required this.source,
    this.date,
    this.detail,
    this.count,
  });

  final T value;
  final InputSource source;
  final DateTime? date;

  /// Précision (type de test…).
  final String? detail;

  /// Nombre de mesures utilisées (FC de repos).
  final int? count;
}

/// Une valeur saisie à la main, datée.
typedef ManualValue<T> = ({T value, DateTime date});

/// VMA : le dernier test, sauf saisie manuelle plus récente que lui.
ProfileValue<double>? resolveVma({
  ManualValue<double>? manual,
  ({double vmaKmh, DateTime date, String kind})? latestTest,
}) {
  final test = latestTest;
  if (manual != null && (test == null || !test.date.isAfter(manual.date))) {
    return ProfileValue(
      value: manual.value,
      source: InputSource.manual,
      date: manual.date,
    );
  }
  if (test == null) return null;
  return ProfileValue(
    value: test.vmaKmh,
    source: InputSource.test,
    date: test.date,
    detail: test.kind,
  );
}

/// FC max : saisie, sinon plus haute relevée, sinon 220 − âge.
ProfileValue<int>? resolveMaxHeartRate({
  ManualValue<int>? manual,
  ManualValue<int>? observed,
  int? birthYear,
  required DateTime now,
}) {
  if (manual != null) {
    return ProfileValue(
      value: manual.value,
      source: InputSource.manual,
      date: manual.date,
    );
  }
  if (observed != null) {
    return ProfileValue(
      value: observed.value,
      source: InputSource.observed,
      date: observed.date,
    );
  }
  if (birthYear == null) return null;
  return ProfileValue(
    value: 220 - (now.year - birthYear),
    source: InputSource.estimated,
  );
}

/// FC de repos : moyenne des [count] dernières mesures « couché » du test
/// orthostatique, sauf saisie manuelle plus récente que la dernière mesure.
ProfileValue<int>? resolveRestHeartRate({
  ManualValue<int>? manual,
  List<({int bpm, DateTime date})> lyingMeasures = const [],
  int count = 5,
}) {
  final recent = [...lyingMeasures]..sort((a, b) => b.date.compareTo(a.date));
  final latest = recent.firstOrNull;
  if (manual != null && (latest == null || !latest.date.isAfter(manual.date))) {
    return ProfileValue(
      value: manual.value,
      source: InputSource.manual,
      date: manual.date,
    );
  }
  if (latest == null) return null;
  final used = recent.take(count).toList();
  return ProfileValue(
    value: (used.fold(0, (s, m) => s + m.bpm) / used.length).round(),
    source: InputSource.orthostatic,
    date: latest.date,
    count: used.length,
  );
}

/// Rappel quand une donnée est ancienne ou peu fiable, sinon `null`.
String? vmaReminder(ProfileValue<double>? vma, DateTime now) {
  if (vma == null) return 'Fais un test de VMA pour calculer tes allures.';
  final date = vma.date;
  if (date == null) return null;
  final weeks = now.difference(date).inDays ~/ 7;
  return weeks >= 8 ? 'Ta VMA date de $weeks semaines : refais un test.' : null;
}

String? maxHeartRateReminder(ProfileValue<int>? maxHr) => switch (maxHr) {
  null => 'Saisis ta FC max, ou ton année de naissance pour une estimation.',
  ProfileValue(source: InputSource.estimated) =>
    'Estimation peu fiable : à remplacer par une vraie mesure (fin de '
        'VAMEVAL, côte à fond).',
  _ => null,
};

String? restHeartRateReminder(ProfileValue<int>? rest, DateTime now) {
  if (rest == null) {
    return 'Fais un test orthostatique, ou saisis ta FC de repos.';
  }
  final date = rest.date;
  if (date == null) return null;
  final weeks = now.difference(date).inDays ~/ 7;
  return weeks >= 4
      ? 'Dernière mesure il y a $weeks semaines : refais un test '
            'orthostatique.'
      : null;
}
