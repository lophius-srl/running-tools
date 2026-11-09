import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/json_file_store.dart';

void main() {
  late Directory dir;
  late JsonFileStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('store_test');
    store = JsonFileStore(File('${dir.path}/data.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('fichier absent : null', () async {
    expect(await store.read(), isNull);
  });

  test('aller-retour, sans fichier temporaire restant', () async {
    await store.write({'version': 1, 'a': 'é'});
    expect(await store.read(), {'version': 1, 'a': 'é'});
    expect(File('${dir.path}/data.json.tmp').existsSync(), isFalse);
  });

  test('fichier corrompu : mis de côté, null', () async {
    File('${dir.path}/data.json').writeAsStringSync('{pas du json');
    expect(await store.read(), isNull);
    expect(File('${dir.path}/data.json.corrupt').existsSync(), isTrue);
    expect(File('${dir.path}/data.json').existsSync(), isFalse);
  });
}
