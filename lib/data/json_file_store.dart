import 'dart:convert';
import 'dart:io';

/// Un document JSON dans un fichier, écrit de façon atomique.
class JsonFileStore {
  JsonFileStore(this.file);

  final File file;

  /// Contenu du fichier, ou `null` s'il est absent. Un fichier illisible est
  /// mis de côté (`.corrupt`) pour ne pas bloquer l'app.
  Future<Map<String, Object?>?> read() async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Traité comme un fichier corrompu ci-dessous.
    }
    await file.rename('${file.path}.corrupt');
    return null;
  }

  Future<void> write(Map<String, Object?> data) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }
}
