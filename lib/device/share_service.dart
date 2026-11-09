import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Partage via la feuille de partage iOS.
abstract interface class ShareService {
  Future<void> shareText(String text, {String? subject});
}

class SharePlusService implements ShareService {
  @override
  Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => SharePlusService(),
);
