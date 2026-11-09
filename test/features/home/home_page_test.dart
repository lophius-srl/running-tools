import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/app.dart';
import 'package:running_tools/features/home/home_entry.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RunningToolsApp()));
  }

  testWidgets('l\'accueil propose les 4 tests et les 2 outils', (tester) async {
    await pumpApp(tester);
    for (final entry in HomeEntry.values) {
      await tester.scrollUntilVisible(find.text(entry.label), 100);
      expect(find.text(entry.label), findsOneWidget);
    }
  });

  testWidgets('un appui ouvre l\'écran correspondant', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('VAMEVAL'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'VAMEVAL'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tests'), findsOneWidget);
  });
}
