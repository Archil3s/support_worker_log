import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;

class LocalSupportNotesPlatform {
  static const String _writerUrl = 'http://127.0.0.1:51239';

  bool hasFolder() => true;

  Future<bool> chooseFolder() async {
    await _post('/ping', <String, dynamic>{});
    return true;
  }

  Future<bool> writeFile({
    required String fileName,
    required String contents,
  }) async {
    await _post('/write-note', <String, dynamic>{
      'fileName': fileName,
      'contents': contents,
    });
    return true;
  }

  Future<bool> renameFile({
    required String oldFileName,
    required String newFileName,
    required String contents,
  }) async {
    await _post('/rename-note', <String, dynamic>{
      'oldFileName': oldFileName,
      'newFileName': newFileName,
      'contents': contents,
    });
    return true;
  }

  Future<bool> openFile(String fileName) async {
    await _post('/open-note', <String, dynamic>{'fileName': fileName});
    return true;
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await js_util
        .promiseToFuture<dynamic>(
          js_util.callMethod(js_util.globalThis, 'fetch', [
            '$_writerUrl$path',
            js_util.jsify({
              'method': 'POST',
              'headers': {'Content-Type': 'text/plain;charset=utf-8'},
              'body': jsonEncode(body),
              'cache': 'no-store',
            }),
          ]),
        )
        .timeout(const Duration(seconds: 25));

    final statusRaw = js_util.getProperty<dynamic>(response, 'status');
    final status = statusRaw is num ? statusRaw.toInt() : 0;

    final text = await js_util.promiseToFuture<String>(
      js_util.callMethod(response, 'text', []),
    );

    if (status < 200 || status >= 300) {
      throw StateError(
        text.trim().isNotEmpty
            ? text
            : 'Local Node notes writer failed with HTTP $status.',
      );
    }

    if (text.trim().isEmpty) return;

    final decoded = jsonDecode(text);

    if (decoded is Map && decoded['ok'] == true) return;

    throw StateError(text);
  }
}
