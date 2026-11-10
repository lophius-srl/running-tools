import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'pcm.dart';
import 'program_renderer.dart';
import 'voice_synthesizer.dart';
import 'wav.dart';

/// Annonces dont le texte n'est connu qu'en course (« 15 mètres »).
abstract interface class LiveVoice {
  Future<void> say(String text);
  Future<void> dispose();
}

/// Phrase synthétisée à la volée, jouée par-dessus la musique, qui n'est
/// baissée que le temps de la phrase.
class TtsLiveVoice implements LiveVoice {
  final _player = AudioPlayer(handleInterruptions: false);
  VoiceSynthesizer? _synth;
  Directory? _dir;
  var _count = 0;
  Future<void> _queue = Future.value();

  @override
  Future<void> say(String text) =>
      _queue = _queue.then((_) => _speak(text)).catchError((_) {});

  Future<void> _speak(String text) async {
    final dir = _dir ??= await getApplicationCacheDirectory();
    final synth = _synth ??= VoiceSynthesizer(
      workDir: dir,
      sampleRate: trackSampleRate,
    );
    final voice = await synth.synthesize(text);
    final pcm = Int16List(voice.length);
    mixInto(pcm, 0, voice);
    final file = File('${dir.path}/live_voice_${_count++ % 4}.wav');
    await file.writeAsBytes(encodeWav(pcm, trackSampleRate));

    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers |
            AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      ),
    );
    await session.setActive(true);
    await _player.setFilePath(file.path);
    await _player.play();
    await _player.processingStateStream.firstWhere(
      (s) => s == ProcessingState.completed,
    );
    await _player.stop();
    // La musique remonte.
    await session.setActive(false);
  }

  @override
  Future<void> dispose() => _player.dispose();
}

final liveVoiceFactoryProvider = Provider<LiveVoice Function()>(
  (ref) => TtsLiveVoice.new,
);
