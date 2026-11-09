import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/progression.dart';
import 'package:running_tools/domain/test_record.dart';

void main() {
  TestRecord record(String id, DateTime date, TestKind kind, double vma) =>
      TestRecord(
        id: id,
        date: date,
        kind: kind,
        vmaKmh: vma,
        vo2max: vma * 3.5,
      );

  final records = [
    record('c', DateTime(2026, 11, 9), TestKind.cooper, 15),
    record('a', DateTime(2026, 9, 1), TestKind.vameval, 14),
    record('b', DateTime(2026, 10, 1), TestKind.vameval, 14.5),
  ];

  test('du plus ancien au plus récent', () {
    final points = progressPoints(
      records,
      metric: ProgressMetric.vma,
      kinds: TestKind.values.toSet(),
    );
    expect(points.map((p) => p.value), [14, 14.5, 15]);
  });

  test('filtre par type de test', () {
    final points = progressPoints(
      records,
      metric: ProgressMetric.vma,
      kinds: {TestKind.cooper},
    );
    expect(points.single.kind, TestKind.cooper);
  });

  test('métrique VO2max', () {
    final points = progressPoints(
      records,
      metric: ProgressMetric.vo2max,
      kinds: {TestKind.vameval},
    );
    expect(points.map((p) => p.value), [49, 50.75]);
  });

  test('aucun type sélectionné : aucun point', () {
    expect(
      progressPoints(records, metric: ProgressMetric.vma, kinds: {}),
      isEmpty,
    );
  });
}
