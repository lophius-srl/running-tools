import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'audio_program.dart';
import 'program_renderer.dart';
import 'voice_synthesizer.dart';
import 'wav.dart';

/// Synthétise les annonces (une fois par texte) puis écrit la piste dans
/// [outputPath]. Renvoie l'erreur de synthèse éventuelle (bips seuls).
Future<String?> buildProgramTrack(
  AudioProgram program, {
  required Directory workDir,
  required String outputPath,
  int sampleRate = trackSampleRate,
  void Function(String step)? onProgress,
}) async {
  final voices = <String, Float32List>{};
  String? voiceError;
  final texts = program.speeches.toList();
  try {
    final synth = VoiceSynthesizer(workDir: workDir, sampleRate: sampleRate);
    for (var i = 0; i < texts.length; i++) {
      onProgress?.call('Synthèse vocale : ${i + 1}/${texts.length}');
      voices[texts[i]] = await synth.synthesize(texts[i]);
    }
  } catch (e) {
    voiceError = e.toString();
    voices.clear();
  }
  onProgress?.call('Mixage de la piste…');
  await Isolate.run(() {
    final renderer = ProgramRenderer(sampleRate: sampleRate);
    writeWavFile(outputPath, renderer.render(program, voices), sampleRate);
  });
  return voiceError;
}
