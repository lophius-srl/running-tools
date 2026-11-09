import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/marker_spacing.dart';

void main() {
  test('terrains normés', () {
    expect(
      {for (final f in StandardField.values) f.label: f.spacingM},
      {
        'Football': 16.5,
        'Handball': 20,
        'Rugby': 22,
        'Tennis': 23.77,
        'Piste d’athlétisme (400 m)': 20,
      },
    );
  });

  test('piste : 400 m est un multiple de l\'espacement', () {
    expect(400 % StandardField.track.spacingM, 0);
  });
}
