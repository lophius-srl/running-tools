import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'device/reminder_scheduler.dart';
import 'features/checklists/race_checklist_page.dart';
import 'features/home/home_page.dart';
import 'features/orthostatic/orthostatic_page.dart';

class RunningToolsApp extends ConsumerStatefulWidget {
  const RunningToolsApp({super.key});

  @override
  ConsumerState<RunningToolsApp> createState() => _RunningToolsAppState();
}

class _RunningToolsAppState extends ConsumerState<RunningToolsApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initReminders();
  }

  /// Toucher un rappel de checklist ouvre la checklist de la course, que
  /// l'app soit ouverte ou lancée par la notification.
  Future<void> _initReminders() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    await scheduler.init(_openChecklist);
    final payload = await scheduler.launchPayload();
    if (payload != null) _openChecklist(payload);
  }

  /// Notification touchée : test orthostatique ou checklist de course.
  void _openChecklist(String payload) => _navigator.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => payload == orthostaticPayload
          ? const OrthostaticPage()
          : RaceChecklistPage(checklistId: payload),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Running Tools',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
