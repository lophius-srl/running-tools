import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'features/home/home_page.dart';

class RunningToolsApp extends StatelessWidget {
  const RunningToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running Tools',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
