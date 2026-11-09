import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/hold_to_confirm.dart';

void main() {
  late int confirmations;

  Future<void> pumpHold(WidgetTester tester) async {
    confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HoldToConfirm(
            duration: const Duration(seconds: 2),
            onConfirmed: () => confirmations++,
            child: const Text('Tenir'),
          ),
        ),
      ),
    );
  }

  Future<void> hold(WidgetTester tester, Duration duration) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tenir')),
    );
    await tester.pump(); // première image : l'animation démarre
    await tester.pump(duration);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('un tap ne confirme pas', (tester) async {
    await pumpHold(tester);
    await tester.tap(find.text('Tenir'));
    await tester.pumpAndSettle();
    expect(confirmations, 0);
  });

  testWidgets('relâcher avant la fin annule', (tester) async {
    await pumpHold(tester);
    await hold(tester, const Duration(milliseconds: 1500));
    expect(confirmations, 0);
  });

  testWidgets('maintenir 2 s confirme une seule fois', (tester) async {
    await pumpHold(tester);
    await hold(tester, const Duration(milliseconds: 2100));
    expect(confirmations, 1);
  });
}
