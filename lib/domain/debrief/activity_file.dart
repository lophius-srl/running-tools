import 'dart:convert';
import 'dart:typed_data';

import 'activity.dart';
import 'fit_reader.dart';
import 'gpx_activity.dart';

/// Lit un fichier de sortie, GPX ou FIT (reconnu à son contenu).
RawActivity parseActivityFile(Uint8List bytes, {required String fileName}) {
  final name = fileName.replaceAll(
    RegExp(r'\.(gpx|fit)$', caseSensitive: false),
    '',
  );
  final isFit =
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == '.FIT';
  return isFit
      ? parseFitActivity(bytes, name: name)
      : parseGpxActivity(
          utf8.decode(bytes, allowMalformed: true),
          fallbackName: name,
        );
}
