import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// Fichier choisi, brut (GPX ou FIT) ; `null` si annulé.
typedef ActivityFilePicker =
    Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> pickActivityFile() async {
  final files = await FilePicker.pickFiles();
  final path = files.singleOrNull?.path;
  if (path == null) return null;
  return (name: files.single.name, bytes: await File(path).readAsBytes());
}

final activityFilePickerProvider = Provider<ActivityFilePicker>(
  (ref) => pickActivityFile,
);
