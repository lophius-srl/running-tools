import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
