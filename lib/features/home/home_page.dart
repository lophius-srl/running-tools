import 'package:flutter/material.dart';

import '../common/coming_soon_page.dart';
import 'home_entry.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, HomeEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComingSoonPage(title: entry.label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(HomeEntry entry) => Card(
      child: ListTile(
        leading: Icon(entry.icon, color: theme.colorScheme.primary),
        title: Text(entry.label),
        subtitle: Text(entry.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, entry),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Running Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tests', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...HomeEntry.tests.map(tile),
          const SizedBox(height: 24),
          Text('Outils', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...HomeEntry.tools.map(tile),
        ],
      ),
    );
  }
}
