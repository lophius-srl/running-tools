import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/tap_grid.dart';

void main() {
  testWidgets('un tap par bouton prêt, rien sur un bouton terminé', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TapGrid(
            items: const [
              TapGridItem(label: 'A', detail: 'Tour 1'),
              TapGridItem(label: 'B', state: TapState.done),
              TapGridItem(label: 'C'),
            ],
            onTap: taps.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('A'));
    await tester.tap(find.text('B'));
    await tester.tap(find.text('C'));
    expect(taps, [0, 2]);
  });

  testWidgets('boutons d\'au moins 96 pt de haut, même à 12 coureurs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TapGrid(
            items: [for (var i = 0; i < 12; i++) TapGridItem(label: '$i')],
            onTap: (_) {},
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(InkWell).first);
    expect(size.height, greaterThanOrEqualTo(96));
  });
}
