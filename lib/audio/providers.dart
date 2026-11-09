import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'beep_player.dart';
import 'track_service.dart';

final trackServiceProvider = FutureProvider<TrackService>(
  (ref) async => CachedTrackService(await getApplicationCacheDirectory()),
);

/// Crée un lecteur ; l'écran qui l'utilise le libère.
final beepPlayerFactoryProvider = Provider<BeepPlayer Function()>(
  (ref) => JustAudioBeepPlayer.new,
);
