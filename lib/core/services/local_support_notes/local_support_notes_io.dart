import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class LocalSupportNotesPlatform {
  static const String defaultRootPath =
      r'C:\Users\Danie\OneDrive\Desktop\MR notes to submit';
  static const String _androidWriterUrl = 'http://10.0.2.2:51239';

  bool hasFolder() {
    return true;
  }

  Future<bool> chooseFolder() async {
    if (Platform.isAndroid) {
      await _post('/ping', <String, dynamic>{});
      return true;
    }

    await Directory(defaultRootPath).create(recursive: true);
    return true;
  }

  Future<bool> writeFile({
    required String fileName,
    required String contents,
  }) async {
    if (Platform.isAndroid) {
      await _post('/write-note', <String, dynamic>{
        'fileName': fileName,
        'contents': contents,
      });
      return true;
    }

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
    if (Platform.isAndroid) {
      await _post('/rename-note', <String, dynamic>{
        'oldFileName': oldFileName,
        'newFileName': newFileName,
        'contents': contents,
      });
      return true;
    }

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
    if (Platform.isAndroid) {
      await _post('/open-note', <String, dynamic>{'fileName': fileName});
      return true;
    }

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

  Future<bool> openFolder(String fileName) async {
    if (Platform.isAndroid) {
      await _post('/open-folder', <String, dynamic>{'fileName': fileName});
      return true;
    }

    final file = await _fileForRelativePath(fileName);

    if (!await file.exists()) {
      throw StateError('Local note file does not exist: ${file.path}');
    }

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.parent.path]);
      return true;
    }

    throw UnsupportedError(
      'Opening folders is currently implemented for Windows only.',
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

Future<void> _post(String path, Map<String, dynamic> body) async {
  final client = HttpClient();

  try {
    final request = await client
        .postUrl(
          Uri.parse('${LocalSupportNotesPlatform._androidWriterUrl}$path'),
        )
        .timeout(const Duration(seconds: 20));

    request.headers.contentType = ContentType(
      'text',
      'plain',
      charset: 'utf-8',
    );

    request.write(jsonEncode(body));

    final response = await request.close().timeout(const Duration(seconds: 20));
    final raw = await utf8.decoder.bind(response).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        raw.trim().isNotEmpty
            ? raw
            : 'Local notes writer failed with HTTP ${response.statusCode}.',
      );
    }

    if (raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw);

    if (decoded is Map && decoded['ok'] == true) return;

    throw StateError(raw);
  } on TimeoutException {
    throw StateError(
      'Local notes writer timed out. Start start_invoice_web.ps1 first.',
    );
  } on SocketException catch (error) {
    throw StateError(
      'Local notes writer is not reachable. Start start_invoice_web.ps1 first. Details: $error',
    );
  } finally {
    client.close(force: true);
  }
}
