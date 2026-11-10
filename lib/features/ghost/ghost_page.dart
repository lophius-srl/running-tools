import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ghost_repository.dart';
import '../../data/providers.dart';
import '../../domain/ghost.dart';
import '../../domain/ghost_announcer.dart';
import '../../domain/gpx.dart';
import '../common/date_text.dart';
import '../common/decimal_text.dart';
import '../common/duration_text.dart';
import '../common/run_widgets.dart';
import '../home/home_entry.dart';
import 'ghost_run_page.dart';

/// Lit le contenu d'un GPX choisi par l'utilisateur ; `null` si annulé.
typedef GpxPicker = Future<({String name, String content})?> Function();

Future<({String name, String content})?> pickGpxFile() async {
  final files = await FilePicker.pickFiles();
  final path = files.singleOrNull?.path;
  if (path == null) return null;
  final file = files.single;
  final bytes = await File(path).readAsBytes();
  return (
    name: file.name.replaceAll(RegExp(r'\.gpx$'), ''),
    content: utf8.decode(bytes, allowMalformed: true),
  );
}

final gpxPickerProvider = Provider<GpxPicker>((ref) => pickGpxFile);

/// « 10,2 km · 52:10 ».
String describeSavedGhost(SavedGhost g) =>
    '${formatDecimal(double.parse((g.distanceM / 1000).toStringAsFixed(1)))} km'
    ' · ${formatClock(g.timeS)}';

/// Choix du fantôme et des réglages, puis historique des courses.
class GhostPage extends ConsumerStatefulWidget {
  const GhostPage({super.key});

  @override
  ConsumerState<GhostPage> createState() => _GhostPageState();
}

class _GhostPageState extends ConsumerState<GhostPage> {
  final _pace = TextEditingController(text: '5:00');
  final _distance = TextEditingController();
  var _saved = <SavedGhost>[];
  var _runs = <GhostRunSummary>[];

  /// `null` : fantôme virtuel ; sinon l'id du fantôme enregistré.
  String? _selected;
  Ghost? _loaded;
  var _alignment = GhostAlignment.distance;
  var _every = GhostAnnounceEvery.kilometer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pace.dispose();
    _distance.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final repo = await ref.read(ghostRepositoryProvider.future);
    final saved = await repo.saved();
    final runs = await repo.runs();
    if (mounted) {
      setState(() {
        _saved = saved;
        _runs = runs;
      });
    }
  }

  Future<void> _select(String? id) async {
    setState(() {
      _selected = id;
      _loaded = null;
      _alignment = GhostAlignment.distance;
    });
    if (id == null) return;
    final repo = await ref.read(ghostRepositoryProvider.future);
    final ghost = await repo.load(id);
    if (mounted && _selected == id) setState(() => _loaded = ghost);
  }

  Future<void> _importGpx() async {
    final picked = await ref.read(gpxPickerProvider)();
    if (picked == null) return;
    try {
      final ghost = parseGpxGhost(picked.content, fallbackName: picked.name);
      final repo = await ref.read(ghostRepositoryProvider.future);
      final entry = await repo.save(ghost);
      await _refresh();
      await _select(entry.id);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(SavedGhost g) async {
    final repo = await ref.read(ghostRepositoryProvider.future);
    await repo.delete(g.id);
    if (_selected == g.id) await _select(null);
    await _refresh();
  }

  Ghost? get _virtual {
    final pace = parseClock(_pace.text);
    if (pace == null || pace < const Duration(minutes: 2)) return null;
    final km = parseDecimal(_distance.text);
    if (_distance.text.trim().isNotEmpty && (km == null || km <= 0)) {
      return null;
    }
    return Ghost.constantPace(pace, distanceKm: km);
  }

  Ghost? get _ghost => _selected == null ? _virtual : _loaded;

  Future<void> _start() async {
    final ghost = _ghost!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GhostRunPage(ghost: ghost, alignment: _alignment, every: _every),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ghost = _ghost;
    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.ghost),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Contre qui ?', style: theme.textTheme.titleMedium),
                RadioGroup<String?>(
                  groupValue: _selected,
                  onChanged: _select,
                  child: Column(
                    children: [
                      const RadioListTile<String?>(
                        value: null,
                        title: Text('Fantôme à allure constante'),
                      ),
                      if (_selected == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('ghost-pace'),
                                  controller: _pace,
                                  keyboardType: TextInputType.datetime,
                                  decoration: const InputDecoration(
                                    labelText: 'Allure',
                                    suffixText: '/km',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const Key('ghost-distance'),
                                  controller: _distance,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Distance (option)',
                                    suffixText: 'km',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final g in _saved)
                        RadioListTile<String?>(
                          value: g.id,
                          title: Text(g.name),
                          subtitle: Text(describeSavedGhost(g)),
                          secondary: IconButton(
                            tooltip: 'Supprimer ${g.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(g),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _importGpx,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Importer un GPX'),
                ),
                const SizedBox(height: 16),
                Text('Comparer', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<GhostAlignment>(
                  segments: [
                    for (final a in GhostAlignment.values)
                      ButtonSegment(
                        value: a,
                        label: Text(a.label),
                        enabled:
                            a == GhostAlignment.distance ||
                            (ghost?.hasRoute ?? false),
                      ),
                  ],
                  selected: {_alignment},
                  onSelectionChanged: (s) =>
                      setState(() => _alignment = s.single),
                ),
                const SizedBox(height: 16),
                Text('Annoncer l’écart', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<GhostAnnounceEvery>(
                  segments: [
                    for (final e in GhostAnnounceEvery.values)
                      ButtonSegment(value: e, label: Text(e.label)),
                  ],
                  selected: {_every},
                  onSelectionChanged: (s) => setState(() => _every = s.single),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: ghost == null ? null : _start,
                  icon: const Icon(Icons.directions_run),
                  label: const Text('Courir contre le fantôme'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                ),
                if (_runs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Mes courses', style: theme.textTheme.titleMedium),
                  for (final r in _runs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.ghostName),
                      subtitle: Text(
                        '${formatDateTime(r.date)} · '
                        '${formatDecimal(double.parse((r.distanceM / 1000).toStringAsFixed(2)))} km',
                      ),
                      trailing: GapText(seconds: r.gapS),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « +12 s » en vert (devant) ou « −8 s » en rouge (derrière).
class GapText extends StatelessWidget {
  const GapText({super.key, required this.seconds, this.style});

  final double seconds;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = seconds.round();
    final color = s >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    return Text(
      formatGap(seconds),
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// « +12 s », « −1:05 ».
String formatGap(double seconds) {
  final s = seconds.round();
  final sign = s > 0 ? '+' : (s < 0 ? '−' : '');
  final a = s.abs();
  return a >= 60
      ? '$sign${a ~/ 60}:${(a % 60).toString().padLeft(2, '0')}'
      : '$sign$a s';
}
