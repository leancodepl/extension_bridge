import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// The suffix of the temporary files [writeFile] and native code write to.
const _temporarySuffix = '.extension_bridge.tmp';

/// Writes [bytes] to [path], creating missing directories.
///
/// The bytes are written to a temporary file first and then moved into
/// place, so an extension never reads a half written file.
Future<String> writeFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  // Unique per write: isolates and processes can write the same name at once.
  final temporary = File(
    '$path.$pid.${Random().nextInt(1 << 32)}$_temporarySuffix',
  );
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(path);
  } finally {
    if (temporary.existsSync()) {
      await temporary.delete();
    }
  }
  return file.path;
}

/// Reads the file at [path], or returns `null` if it does not exist.
Future<Uint8List?> readFile(String path) async {
  final file = File(path);
  return file.existsSync() ? await file.readAsBytes() : null;
}

/// Whether a file exists at [path].
Future<bool> fileExists(String path) async => File(path).existsSync();

/// Deletes the file at [path] and returns whether it existed.
Future<bool> deleteFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return false;
  }
  await file.delete();
  return true;
}

/// Lists the files below [directory] as paths relative to it.
Future<List<String>> listFiles(String directory) async {
  final root = Directory(directory);
  if (!root.existsSync()) {
    return [];
  }
  final prefixLength = root.absolute.path.length + 1;
  return [
    await for (final entity in root.list(recursive: true))
      if (entity is File && !entity.path.endsWith(_temporarySuffix))
        entity.absolute.path
            .substring(prefixLength)
            .replaceAll(Platform.pathSeparator, '/'),
  ]..sort();
}

/// Deletes everything inside [directory] but keeps the directory itself.
Future<void> clearDirectory(String directory) async {
  final root = Directory(directory);
  if (!root.existsSync()) {
    return;
  }
  await for (final entity in root.list()) {
    await entity.delete(recursive: true);
  }
}
