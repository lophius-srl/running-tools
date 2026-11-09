import 'test_record.dart';

/// Grandeur suivie sur le graphe de progression.
enum ProgressMetric {
  vma('VMA', 'km/h'),
  vo2max('VO2max', 'ml/kg/min');

  const ProgressMetric(this.label, this.unit);

  final String label;
  final String unit;

  double of(TestRecord record) => switch (this) {
    vma => record.vmaKmh,
    vo2max => record.vo2max,
  };
}

/// Un point du graphe : un test enregistré.
class ProgressPoint {
  const ProgressPoint(this.date, this.value, this.kind);

  final DateTime date;
  final double value;
  final TestKind kind;
}

/// Points du plus ancien au plus récent, limités aux tests de [kinds].
List<ProgressPoint> progressPoints(
  List<TestRecord> records, {
  required ProgressMetric metric,
  required Set<TestKind> kinds,
}) => [
  for (final r in records)
    if (kinds.contains(r.kind)) ProgressPoint(r.date, metric.of(r), r.kind),
]..sort((a, b) => a.date.compareTo(b.date));
