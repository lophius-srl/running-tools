import 'package:flutter/material.dart';

import 'ar_spike_page.dart';
import 'audio_spike_page.dart';

/// Accès aux écrans de spike (temporaire, avant l'app complète).
class SpikeMenuPage extends StatelessWidget {
  const SpikeMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Running Tools · spikes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Spike audio'),
            subtitle: const Text('Piste VAMEVAL 15 min, repères 20 m'),
            onTap: () => open(const AudioSpikePage()),
          ),
          ListTile(
            leading: const Icon(Icons.view_in_ar),
            title: const Text('Spike AR'),
            subtitle: const Text('Pose un départ, marche, bip tous les N m'),
            onTap: () => open(const ArSpikePage()),
          ),
        ],
      ),
    );
  }
}
