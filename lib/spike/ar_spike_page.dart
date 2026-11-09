import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/pcm.dart';
import '../audio/wav.dart';
import '../domain/distance_tracker.dart';

/// Spike : poser un point de départ au sol, marcher en visant le sol, bip +
/// vibration + repère virtuel tous les N mètres.
class ArSpikePage extends StatefulWidget {
  const ArSpikePage({super.key});

  @override
  State<ArSpikePage> createState() => _ArSpikePageState();
}

class _ArSpikePageState extends State<ArSpikePage> {
  static const _sampleInterval = Duration(milliseconds: 66);
  static const _sampleRate = 22050;

  ARKitController? _ar;
  Timer? _sampler;
  var _sampling = false;
  final _markerPlayer = AudioPlayer(handleInterruptions: false);
  final _alertPlayer = AudioPlayer(handleInterruptions: false);
  final _spacingController = TextEditingController(text: '20');

  var _mode = DistanceMode.path;
  DistanceTracker? _tracker;
  Vector3? _aim;
  var _floorFound = false;
  ARTrackingState _trackingState = ARTrackingState.notAvailable;
  ARTrackingStateReason? _trackingReason;
  final _nodeNames = <String>[];

  bool get _trackingOk => _trackingState == ARTrackingState.normal;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _prepareSounds();
  }

  Future<void> _prepareSounds() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
      ),
    );
    final dir = await getTemporaryDirectory();
    final marker = tone(
      sampleRate: _sampleRate,
      frequencyHz: 1000,
      duration: const Duration(milliseconds: 200),
    );
    final alert = sequence([
      for (var i = 0; i < 2; i++)
        tone(
          sampleRate: _sampleRate,
          frequencyHz: 400,
          duration: const Duration(milliseconds: 150),
        ),
    ], 2205);
    await _markerPlayer.setFilePath(await _writeSound(dir, 'marker', marker));
    await _alertPlayer.setFilePath(await _writeSound(dir, 'alert', alert));
  }

  Future<String> _writeSound(
    Directory dir,
    String name,
    Float32List samples,
  ) async {
    final path = '${dir.path}/ar_$name.wav';
    final pcm = Int16List(samples.length);
    mixInto(pcm, 0, samples);
    await File(path).writeAsBytes(encodeWav(pcm, _sampleRate));
    return path;
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _sampler?.cancel();
    _ar?.dispose();
    _markerPlayer.dispose();
    _alertPlayer.dispose();
    _spacingController.dispose();
    super.dispose();
  }

  void _onArCreated(ARKitController controller) {
    _ar = controller
      ..onAddNodeForAnchor = (anchor) {
        if (anchor is ARKitPlaneAnchor && !_floorFound) {
          setState(() => _floorFound = true);
        }
      }
      ..onCameraDidChangeTrackingState = _onTrackingChanged;
    _sampler = Timer.periodic(_sampleInterval, (_) => _sample());
  }

  void _onTrackingChanged(ARTrackingState state, ARTrackingStateReason? why) {
    final wasOk = _trackingOk;
    setState(() {
      _trackingState = state;
      _trackingReason = why;
    });
    final tracker = _tracker;
    if (tracker == null) return;
    if (wasOk && !_trackingOk) {
      tracker.pause();
      _play(_alertPlayer);
      HapticFeedback.vibrate();
    } else if (_trackingOk) {
      tracker.resume();
    }
  }

  Future<void> _sample() async {
    final ar = _ar;
    if (ar == null || _sampling) return;
    _sampling = true;
    try {
      final hits = await ar.performHitTest(x: 0.5, y: 0.5);
      final floor = hits.where(
        (h) =>
            h.type == ARKitHitTestResultType.existingPlane ||
            h.type == ARKitHitTestResultType.existingPlaneUsingExtent,
      );
      final aim = floor.isEmpty
          ? null
          : floor.first.worldTransform.getTranslation();
      if (!mounted) return;
      setState(() => _aim = aim);
      final tracker = _tracker;
      if (aim != null && tracker != null) {
        for (final crossing in tracker.update(GroundPoint(aim.x, aim.z))) {
          _onMarker(crossing, aim.y);
        }
      }
    } finally {
      _sampling = false;
    }
  }

  void _onMarker(MarkerCrossing crossing, double floorY) {
    _play(_markerPlayer);
    HapticFeedback.heavyImpact();
    _addNode(
      ARKitCylinder(
        radius: 0.08,
        height: 0.5,
        materials: [_material(Colors.orange)],
      ),
      Vector3(crossing.point.x, floorY + 0.25, crossing.point.z),
    );
    setState(() {});
  }

  void _placeStart() {
    final aim = _aim;
    final spacing = double.tryParse(
      _spacingController.text.replaceAll(',', '.'),
    );
    if (aim == null || spacing == null || spacing <= 0) return;
    _clearNodes();
    _tracker = DistanceTracker(spacingM: spacing, mode: _mode)
      ..start(GroundPoint(aim.x, aim.z));
    _addNode(
      ARKitSphere(radius: 0.08, materials: [_material(Colors.green)]),
      Vector3(aim.x, aim.y + 0.08, aim.z),
    );
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _reset() {
    _clearNodes();
    setState(() => _tracker = null);
  }

  void _addNode(ARKitGeometry geometry, Vector3 position) {
    final node = ARKitNode(geometry: geometry, position: position);
    _nodeNames.add(node.name);
    _ar?.add(node);
  }

  void _clearNodes() {
    for (final name in _nodeNames) {
      _ar?.remove(name);
    }
    _nodeNames.clear();
  }

  ARKitMaterial _material(Color color) =>
      ARKitMaterial(diffuse: ARKitMaterialProperty.color(color));

  Future<void> _play(AudioPlayer player) async {
    await player.seek(Duration.zero);
    player.play();
  }

  String get _trackingLabel => switch (_trackingReason) {
    ARTrackingStateReason.excessiveMotion => 'mouvement trop rapide',
    ARTrackingStateReason.insufficientFeatures =>
      'pas assez de détails (lumière, texture du sol)',
    ARTrackingStateReason.initializing => 'initialisation',
    ARTrackingStateReason.relocalizing => 'relocalisation',
    _ => 'suivi indisponible',
  };

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    final theme = Theme.of(context);
    final aimColor = _aim != null && _trackingOk
        ? Colors.greenAccent
        : Colors.white54;

    return Scaffold(
      appBar: AppBar(title: const Text('Spike AR · repères')),
      body: Stack(
        children: [
          ARKitSceneView(
            onARKitViewCreated: _onArCreated,
            planeDetection: ARPlaneDetection.horizontal,
          ),
          Center(
            child: Icon(Icons.add_circle_outline, size: 48, color: aimColor),
          ),
          if (tracker != null && !_trackingOk)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withValues(alpha: 0.85),
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Suivi perdu : $_trackingLabel. Mesure en pause.',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tracker == null
                        ? (_floorFound
                              ? 'Vise le départ au sol puis pose-le'
                              : 'Balaie le sol avec la caméra…')
                        : '${tracker.distanceM.toStringAsFixed(2)} m',
                    style: tracker == null
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.displaySmall,
                  ),
                  if (tracker != null)
                    Text('${tracker.markersCrossed} repère(s) posé(s)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _spacingController,
                          enabled: tracker == null,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Espacement',
                            suffixText: 'm',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<DistanceMode>(
                          segments: const [
                            ButtonSegment(
                              value: DistanceMode.path,
                              label: Text('Chemin'),
                            ),
                            ButtonSegment(
                              value: DistanceMode.straightLine,
                              label: Text('Ligne droite'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: tracker == null
                              ? (s) => setState(() => _mode = s.single)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  tracker == null
                      ? FilledButton.icon(
                          onPressed: _aim != null && _trackingOk
                              ? _placeStart
                              : null,
                          icon: const Icon(Icons.flag),
                          label: const Text('Poser le départ'),
                        )
                      : OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Recommencer'),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
