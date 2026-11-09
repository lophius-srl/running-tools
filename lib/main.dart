import 'package:flutter/material.dart';

import 'spike/spike_menu_page.dart';

void main() => runApp(const RunningToolsApp());

class RunningToolsApp extends StatelessWidget {
  const RunningToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running Tools',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const SpikeMenuPage(),
    );
  }
}
