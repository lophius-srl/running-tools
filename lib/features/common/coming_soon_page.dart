import 'package:flutter/material.dart';

/// Écran provisoire pour une fonctionnalité pas encore développée.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Bientôt disponible')),
    );
  }
}
