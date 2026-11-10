import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/debrief/activity_file.dart';
import '../../domain/debrief/clean_activity.dart';
import '../../domain/debrief/session_type.dart';
import '../common/gpx_picker.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'activity_summary_page.dart';

/// Débriefs de sortie : import d'une sortie GPX ou FIT.
class DebriefsPage extends ConsumerStatefulWidget {
  const DebriefsPage({super.key});

  @override
  ConsumerState<DebriefsPage> createState() => _DebriefsPageState();
}

class _DebriefsPageState extends ConsumerState<DebriefsPage> {
  var _busy = false;

  Future<void> _import() async {
    final picked = await ref.read(activityFilePickerProvider)();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final raw = parseActivityFile(picked.bytes, fileName: picked.name);
      final activity = CleanActivity.from(raw);
      final history = await ref.read(historyRepositoryProvider.future);
      final vma = (await history.all()).firstOrNull?.vmaKmh;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivitySummaryPage(
            activity: activity,
            detected: detectSessionType(activity, vmaKmh: vma),
            vmaKmh: vma,
          ),
        ),
      );
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const RunHeader(entry: HomeEntry.debrief),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Importe une sortie pour savoir comment mieux gérer ta course : '
                'allure, relief, cardio, cadence.',
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Depuis Strava : sur strava.com, ouvre l’activité, menu '
                    '« … » > « Exporter le GPX » (ou « Exporter l’original » '
                    'pour le fichier FIT de ta montre). Garmin Connect : roue '
                    'dentée > « Exporter l’original ». Enregistre le fichier '
                    'dans Fichiers, puis importe-le ici.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_open),
                label: const Text('Importer une sortie (GPX ou FIT)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
