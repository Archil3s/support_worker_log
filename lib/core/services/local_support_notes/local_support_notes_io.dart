import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class LocalSupportNotesPlatform {
  static const String defaultRootPath = r'C:\Users\Danie\MR NOTES FOLDER';

  bool hasFolder() {
    return true;
  }

  Future<bool> chooseFolder() async {
    await Directory(defaultRootPath).create(recursive: true);
    return true;
  }

  Future<bool> writeFile({
    required String fileName,
    required String contents,
  }) async {
    final file = await _fileForRelativePath(fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(_payloadBytes(contents), flush: true);
    return true;
  }

  Future<bool> renameFile({
    required String oldFileName,
    required String newFileName,
    required String contents,
  }) async {
    final newFile = await _fileForRelativePath(newFileName);
    await newFile.parent.create(recursive: true);
    await newFile.writeAsBytes(_payloadBytes(contents), flush: true);

    if (oldFileName.isNotEmpty && oldFileName != newFileName) {
      final oldFile = await _fileForRelativePath(oldFileName);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    return true;
  }

  Future<bool> openFile(String fileName) async {
    final file = await _fileForRelativePath(fileName);

    if (!await file.exists()) {
      throw StateError('Local note file does not exist: ${file.path}');
    }

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
      return true;
    }

    throw UnsupportedError(
      'Opening files is currently implemented for Windows only.',
    );
  }

  Future<File> _fileForRelativePath(String relativePath) async {
    final root = Directory(defaultRootPath);
    await root.create(recursive: true);

    final safeParts = relativePath
        .replaceAll('\\', '/')
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => part != '.' && part != '..')
        .toList();

    if (safeParts.isEmpty) {
      throw StateError('Invalid note file name.');
    }

    final path = [root.path, ...safeParts].join(Platform.pathSeparator);
    return File(path);
  }

  List<int> _payloadBytes(String contents) {
    if (contents.startsWith('__BASE64__:')) {
      return Uint8List.fromList(
        base64Decode(contents.substring('__BASE64__:'.length)),
      );
    }

    return utf8.encode(contents);
  }
}
