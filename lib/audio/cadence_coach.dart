import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/cadence_advice.dart';
import 'pcm.dart';
import 'program_renderer.dart';
import 'voice_synthesizer.dart';
import 'wav.dart';

/// Joue les conseils de cadence, mixés par-dessus le métronome.
abstract interface class CadenceCoach {
  Future<void> prepare();
  Future<void> say(CadenceAdvice advice);
  Future<void> dispose();
}

/// Phrases synthétisées une fois en WAV, jouées sur un second lecteur.
class TtsCadenceCoach implements CadenceCoach {
  final _player = AudioPlayer(handleInterruptions: false);
  final _paths = <CadenceAdvice, String>{};

  @override
  Future<void> prepare() async {
    final dir = await getApplicationCacheDirectory();
    final synth = VoiceSynthesizer(workDir: dir, sampleRate: trackSampleRate);
    for (final advice in CadenceAdvice.values) {
      final file = File('${dir.path}/coach_${advice.name}.wav');
      if (!file.existsSync()) {
        final voice = await synth.synthesize(advice.phrase);
        final pcm = Int16List(voice.length);
        mixInto(pcm, 0, voice);
        await file.writeAsBytes(encodeWav(pcm, trackSampleRate));
      }
      _paths[advice] = file.path;
    }
  }

  @override
  Future<void> say(CadenceAdvice advice) async {
    final path = _paths[advice];
    if (path == null) return;
    await _player.setFilePath(path);
    await _player.play();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// Crée un coach ; l'écran qui l'utilise le libère.
final cadenceCoachFactoryProvider = Provider<CadenceCoach Function()>(
  (ref) => TtsCadenceCoach.new,
);
