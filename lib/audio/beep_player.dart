import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Lit la piste pré-générée d'un test. Isole le natif du reste de l'app.
abstract interface class BeepPlayer {
  Stream<Duration> get positionStream;
  Duration get position;
  Stream<bool> get playingStream;

  /// Configure la session audio. [duckOthers] baisse la musique des autres
  /// apps pendant toute la lecture ; sinon les bips se mixent par-dessus.
  Future<void> configure({required bool duckOthers});
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Arrête et rend la main aux autres apps (la musique remonte).
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioBeepPlayer implements BeepPlayer {
  // handleInterruptions : pause pendant un appel, reprise automatique ensuite.
  final _player = AudioPlayer(handleInterruptions: true);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Duration get position => _player.position;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> configure({required bool duckOthers}) async {
    final session = await AudioSession.instance;
    var options = AVAudioSessionCategoryOptions.mixWithOthers;
    if (duckOthers) {
      options = options | AVAudioSessionCategoryOptions.duckOthers;
    }
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: options,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      ),
    );
  }

  @override
  Future<void> load(String path) => _player.setFilePath(path);

  @override
  Future<void> play() async {
    // play() ne se termine qu'à la pause ou à la fin : on ne l'attend pas.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  Future<void> dispose() => _player.dispose();
}
