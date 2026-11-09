import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_tts/flutter_tts.dart';

import 'pcm.dart';
import 'wav.dart';

/// Génère des annonces vocales en fichiers puis les décode pour le mixage.
class VoiceSynthesizer {
  VoiceSynthesizer({required this.workDir, required this.sampleRate});

  final Directory workDir;
  final int sampleRate;
  final _tts = FlutterTts();
  var _ready = false;
  var _counter = 0;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSynthCompletion(true);
    // Sinon flutter_tts désactive la session audio partagée après chaque
    // synthèse quand duckOthers est actif.
    await _tts.autoStopSharedSession(false);
    _ready = true;
  }

  /// Renvoie l'annonce à [sampleRate], normalisée.
  Future<Float32List> synthesize(String text) async {
    await _init();
    final file = File('${workDir.path}/voice_${_counter++}.wav');
    if (file.existsSync()) file.deleteSync();
    final result = await _tts
        .synthesizeToFile(text, file.path, true)
        .timeout(const Duration(seconds: 15));
    if (result != 1 || !file.existsSync()) {
      throw StateError('Synthèse vocale échouée ($result) pour « $text »');
    }
    final audio = decodeWav(await file.readAsBytes());
    file.deleteSync();
    return normalize(resample(audio.samples, audio.sampleRate, sampleRate));
  }
}
