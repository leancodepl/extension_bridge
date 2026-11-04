@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:extension_bridge/src/platform/files/file_access_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('extension_bridge_test');
  });

  tearDown(() => directory.delete(recursive: true));

  test('concurrent writes to one name leave one complete file', () async {
    final path = '${directory.path}/a.bin';
    final contents = [
      for (var i = 0; i < 50; i++) Uint8List(1 << 16)..fillRange(0, 1 << 16, i),
    ];

    await Future.wait(contents.map((it) => writeFile(path, it)));

    final written = await readFile(path);
    expect(written!.toSet(), hasLength(1));
    expect(written, hasLength(1 << 16));
    expect(await listFiles(directory.path), ['a.bin']);
  });

  test('listing hides temporary files of writes in progress', () async {
    File('${directory.path}/a.bin').writeAsBytesSync([1]);
    File('${directory.path}/a.bin.1.2.extension_bridge.tmp')
        .writeAsBytesSync([2]);

    expect(await listFiles(directory.path), ['a.bin']);
  });
}
