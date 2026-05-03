// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
    html.HttpRequest response;

    try {
      response = await html.HttpRequest.request(
        '$_writerUrl$path',
        method: 'POST',
        requestHeaders: const {'Content-Type': 'text/plain;charset=utf-8'},
        sendData: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw StateError(
        'Local notes writer timed out. Start the app with start_invoice_web.ps1.',
      );
    } catch (error) {
      throw StateError(
        'Local notes writer is not reachable. Start the app with start_invoice_web.ps1. Details: $error',
      );
    }

    final status = response.status ?? 0;
    final raw = response.responseText ?? '';

    if (status < 200 || status >= 300) {
      throw StateError(
        raw.trim().isNotEmpty
            ? raw
            : 'Local notes writer failed with HTTP $status.',
      );
    }

    if (raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw);

    if (decoded is Map && decoded['ok'] == true) return;

    throw StateError(raw);
  }
}
