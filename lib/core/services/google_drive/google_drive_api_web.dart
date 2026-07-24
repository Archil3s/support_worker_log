// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import '../../models/google_drive_file.dart';

const _desktopDriveProxyPort = 51243;

class GoogleDriveApiPlatform {
  Future<GoogleDriveFile> createFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/create_folder',
        {'accessToken': accessToken, 'name': name, 'parentId': parentId},
        failureMessage: 'Google Drive folder creation failed',
      );
      final file = _fileFromJson(decoded);
      if (file == null) {
        throw StateError(
          'Google Drive folder creation failed: invalid response.',
        );
      }
      return file;
    }

    final body = <String, Object?>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentId != null && parentId.trim().isNotEmpty) 'parents': [parentId],
    };

    final response = await _request(
      _driveFilesUri.toString(),
      method: 'POST',
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=utf-8',
      },
      sendData: jsonEncode(body),
      failureMessage: 'Google Drive folder creation failed',
    );

    return _fileFromResponse(response, 'Google Drive folder creation failed');
  }

  Future<GoogleDriveFile> uploadFile({
    required String accessToken,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required String parentId,
    String? contentMimeType,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/upload_file',
        {
          'accessToken': accessToken,
          'name': name,
          'mimeType': mimeType,
          'parentId': parentId,
          'contentMimeType': contentMimeType,
          'bytesBase64': base64Encode(bytes),
        },
        failureMessage: 'Google Drive upload failed',
      );
      final file = _fileFromJson(decoded);
      if (file == null) {
        throw StateError('Google Drive upload failed: invalid response.');
      }
      return file;
    }

    final boundary =
        'support_worker_log_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = <String, Object?>{
      'name': name,
      'mimeType': mimeType,
      'parents': [parentId],
    };
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=utf-8\r\n\r\n'
          '${jsonEncode(metadata)}\r\n'
          '--$boundary\r\n'
          'Content-Type: ${contentMimeType ?? mimeType}\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final response = await _request(
      _driveUploadUri.toString(),
      method: 'POST',
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      sendData: body.takeBytes(),
      failureMessage: 'Google Drive upload failed',
    );

    return _fileFromResponse(response, 'Google Drive upload failed');
  }

  Future<GoogleDriveFile> updateFile({
    required String accessToken,
    required String fileId,
    required String name,
    required String mimeType,
    required List<int> bytes,
    String? contentMimeType,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/update_file',
        {
          'accessToken': accessToken,
          'fileId': fileId,
          'name': name,
          'mimeType': mimeType,
          'contentMimeType': contentMimeType,
          'bytesBase64': base64Encode(bytes),
        },
        failureMessage: 'Google Drive file update failed',
      );
      final file = _fileFromJson(decoded);
      if (file == null) {
        throw StateError('Google Drive file update failed: invalid response.');
      }
      return file;
    }

    final boundary =
        'support_worker_log_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = <String, Object?>{'name': name, 'mimeType': mimeType};
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=utf-8\r\n\r\n'
          '${jsonEncode(metadata)}\r\n'
          '--$boundary\r\n'
          'Content-Type: ${contentMimeType ?? mimeType}\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final response = await _request(
      _driveUpdateUri(fileId).toString(),
      method: 'PATCH',
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      sendData: body.takeBytes(),
      failureMessage: 'Google Drive file update failed',
    );

    return _fileFromResponse(response, 'Google Drive file update failed');
  }

  Future<GoogleDriveFile> moveFile({
    required String accessToken,
    required String fileId,
    required String fromParentId,
    required String toParentId,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/move_file',
        {
          'accessToken': accessToken,
          'fileId': fileId,
          'fromParentId': fromParentId,
          'toParentId': toParentId,
        },
        failureMessage: 'Google Drive file move failed',
      );
      final file = _fileFromJson(decoded);
      if (file == null) {
        throw StateError('Google Drive file move failed: invalid response.');
      }
      return file;
    }

    final response = await _request(
      _driveMoveUri(
        fileId: fileId,
        fromParentId: fromParentId,
        toParentId: toParentId,
      ).toString(),
      method: 'PATCH',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Drive file move failed',
    );

    return _fileFromResponse(response, 'Google Drive file move failed');
  }

  Future<void> deleteFile({
    required String accessToken,
    required String fileId,
  }) async {
    if (_useDesktopProxy) {
      await _proxyJson(
        '/__google_drive/delete_file',
        {'accessToken': accessToken, 'fileId': fileId},
        failureMessage: 'Google Drive file removal failed',
      );
      return;
    }

    await _request(
      _driveFileUri(fileId).toString(),
      method: 'DELETE',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Drive file removal failed',
    );
  }

  Future<String> exportGoogleDocText({
    required String accessToken,
    required String fileId,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/export_google_doc_text',
        {'accessToken': accessToken, 'fileId': fileId},
        failureMessage: 'Google Docs text export failed',
      );
      return (decoded['text'] as String? ?? '').trim();
    }

    final response = await _request(
      _driveExportUri(fileId, mimeType: 'text/plain').toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Docs text export failed',
    );

    return _decodeTextResponse(
      response,
      failureMessage: 'Google Docs text export failed',
    ).trim();
  }

  Future<Uint8List> exportGoogleDocDocx({
    required String accessToken,
    required String fileId,
  }) async {
    const docxMimeType =
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/export_google_doc_docx',
        {'accessToken': accessToken, 'fileId': fileId},
        failureMessage: 'Google Docs Word download failed',
      );
      final encoded = decoded['bytesBase64'] as String? ?? '';
      if (encoded.isEmpty) {
        throw StateError('Google Docs Word download returned an empty file.');
      }
      return Uint8List.fromList(base64Decode(encoded));
    }

    final response = await _request(
      _driveExportUri(fileId, mimeType: docxMimeType).toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Docs Word download failed',
      responseType: 'arraybuffer',
    );

    return _decodeBinaryResponse(
      response,
      failureMessage: 'Google Docs Word download failed',
    );
  }

  Future<Uint8List> downloadFile({
    required String accessToken,
    required String fileId,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/download_file',
        {'accessToken': accessToken, 'fileId': fileId},
        failureMessage: 'Google Drive file download failed',
      );
      final encoded = decoded['bytesBase64'] as String? ?? '';
      if (encoded.isEmpty) {
        throw StateError('Google Drive file download returned an empty file.');
      }
      return Uint8List.fromList(base64Decode(encoded));
    }

    final response = await _request(
      _driveDownloadUri(fileId).toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Drive file download failed',
      responseType: 'arraybuffer',
    );

    return _decodeBinaryResponse(
      response,
      failureMessage: 'Google Drive file download failed',
    );
  }

  Future<List<GoogleDriveFile>> listChildren({
    required String accessToken,
    required String parentId,
  }) async {
    if (_useDesktopProxy) {
      final decoded = await _proxyJson(
        '/__google_drive/list_children',
        {'accessToken': accessToken, 'parentId': parentId},
        failureMessage: 'Google Drive file listing failed',
      );
      final files = decoded['files'];
      if (files is! List) return const [];

      return files
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_fileFromJson)
          .whereType<GoogleDriveFile>()
          .toList();
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'fields': 'files(id,name,mimeType,webViewLink)',
      'orderBy': 'folder,name',
      'q': "'$parentId' in parents and trashed = false",
    });

    final response = await _request(
      uri.toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
      failureMessage: 'Google Drive file listing failed',
    );
    final decoded = _decodeJsonResponse(
      response,
      failureMessage: 'Google Drive file listing failed',
    );
    final files = decoded['files'];
    if (files is! List) return const [];

    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_fileFromJson)
        .whereType<GoogleDriveFile>()
        .toList();
  }

  Uri get _driveFilesUri {
    return Uri.https('www.googleapis.com', '/drive/v3/files', {
      'fields': 'id,name,mimeType,webViewLink',
    });
  }

  Uri get _driveUploadUri {
    return Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
      'uploadType': 'multipart',
      'fields': 'id,name,mimeType,webViewLink',
    });
  }

  Uri _driveUpdateUri(String fileId) {
    return Uri.https('www.googleapis.com', '/upload/drive/v3/files/$fileId', {
      'uploadType': 'multipart',
      'fields': 'id,name,mimeType,webViewLink',
    });
  }

  Uri _driveMoveUri({
    required String fileId,
    required String fromParentId,
    required String toParentId,
  }) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'addParents': toParentId,
      'removeParents': fromParentId,
      'fields': 'id,name,mimeType,webViewLink',
    });
  }

  Uri _driveFileUri(String fileId) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'fields': 'id,name,mimeType,webViewLink',
    });
  }

  Uri _driveDownloadUri(String fileId) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'alt': 'media',
    });
  }

  Uri _driveExportUri(String fileId, {required String mimeType}) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$fileId/export', {
      'mimeType': mimeType,
    });
  }

  bool get _useDesktopProxy {
    final location = html.window.location;
    final host = location.hostname;

    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  Future<Map<String, dynamic>> _proxyJson(
    String path,
    Map<String, Object?> payload, {
    required String failureMessage,
  }) async {
    final response = await _request(
      '$_desktopDriveProxyOrigin$path',
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json; charset=utf-8'},
      sendData: jsonEncode(payload),
      failureMessage: failureMessage,
    );

    return _decodeJsonResponse(response, failureMessage: failureMessage);
  }

  GoogleDriveFile _fileFromResponse(
    html.HttpRequest response,
    String failureMessage,
  ) {
    final decoded = _decodeJsonResponse(
      response,
      failureMessage: failureMessage,
    );
    final file = _fileFromJson(decoded);
    if (file == null) throw StateError('$failureMessage: invalid response.');
    return file;
  }

  Future<html.HttpRequest> _request(
    String url, {
    required String method,
    required Map<String, String> requestHeaders,
    required String failureMessage,
    Object? sendData,
    String? responseType,
  }) async {
    final completer = Completer<html.HttpRequest>();
    final request = html.HttpRequest()
      ..open(method, url)
      ..timeout = 15000;
    if (responseType != null) {
      request.responseType = responseType;
    }

    for (final entry in requestHeaders.entries) {
      request.setRequestHeader(entry.key, entry.value);
    }

    request.onLoad.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    });
    request.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(_networkFailure(url, failureMessage)),
        );
      }
    });
    request.onTimeout.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('$failureMessage timed out.'));
      }
    });

    request.send(sendData);

    return completer.future;
  }

  Map<String, dynamic> _decodeJsonResponse(
    html.HttpRequest response, {
    required String failureMessage,
  }) {
    final raw = response.responseText ?? '';
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      final googleMessage = _googleApiError(raw);

      throw StateError(
        googleMessage ??
            (raw.trim().isEmpty ? '$failureMessage with HTTP $status.' : raw),
      );
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('$failureMessage returned invalid JSON.');
    }

    return decoded;
  }

  String _decodeTextResponse(
    html.HttpRequest response, {
    required String failureMessage,
  }) {
    final raw = response.responseText ?? '';
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      throw StateError(
        _googleApiError(raw) ?? '$failureMessage with HTTP $status.',
      );
    }

    return raw;
  }

  Uint8List _decodeBinaryResponse(
    html.HttpRequest response, {
    required String failureMessage,
  }) {
    final value = response.response;
    final bytes = switch (value) {
      ByteBuffer buffer => buffer.asUint8List(),
      Uint8List typed => typed,
      List<int> list => Uint8List.fromList(list),
      _ => Uint8List(0),
    };
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      final raw = utf8.decode(bytes, allowMalformed: true);
      throw StateError(
        _googleApiError(raw) ?? '$failureMessage with HTTP $status.',
      );
    }

    if (bytes.isEmpty) {
      throw StateError('$failureMessage returned an empty file.');
    }

    return bytes;
  }

  GoogleDriveFile? _fileFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final mimeType = json['mimeType'] as String? ?? '';

    if (id.trim().isEmpty || name.trim().isEmpty) return null;

    return GoogleDriveFile(
      id: id,
      name: name,
      mimeType: mimeType,
      webViewLink: json['webViewLink'] as String?,
    );
  }

  String? _googleApiError(String raw) {
    if (raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        final status = error['status'];

        if (message is String && message.trim().isNotEmpty) {
          final cleanStatus = status is String && status.trim().isNotEmpty
              ? ' ($status)'
              : '';
          return 'Google Drive API error$cleanStatus: ${message.trim()}';
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String get _desktopDriveProxyOrigin {
    final location = html.window.location;

    if (location.port != '$_desktopDriveProxyPort' ||
        location.hostname == '127.0.0.1' ||
        location.hostname == '::1') {
      return 'http://localhost:$_desktopDriveProxyPort';
    }

    return location.origin;
  }

  String _networkFailure(String url, String failureMessage) {
    if (url.contains('/__google_drive/')) {
      return '$failureMessage. The desktop Google Drive proxy could not be '
          'reached. Restart the Support Worker Log desktop app and try again.';
    }

    return '$failureMessage. The browser could not reach the Google Drive API. '
        'Check that Google Drive API is enabled for this Firebase/Google project.';
  }
}
