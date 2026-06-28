import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/google_drive_file.dart';

class GoogleDriveApiPlatform {
  Future<GoogleDriveFile> createFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) async {
    final decoded = await _jsonRequest(
      _driveFilesUri,
      method: 'POST',
      accessToken: accessToken,
      body: {
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentId != null && parentId.trim().isNotEmpty)
          'parents': [parentId],
      },
      failureMessage: 'Google Drive folder creation failed',
    );

    return _fileFromJson(decoded, 'Google Drive folder creation failed');
  }

  Future<GoogleDriveFile> uploadFile({
    required String accessToken,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required String parentId,
    String? contentMimeType,
  }) async {
    final decoded = await _multipartRequest(
      _driveUploadUri,
      method: 'POST',
      accessToken: accessToken,
      metadata: {
        'name': name,
        'mimeType': mimeType,
        'parents': [parentId],
      },
      bytes: bytes,
      contentMimeType: contentMimeType ?? mimeType,
      failureMessage: 'Google Drive upload failed',
    );

    return _fileFromJson(decoded, 'Google Drive upload failed');
  }

  Future<GoogleDriveFile> updateFile({
    required String accessToken,
    required String fileId,
    required String name,
    required String mimeType,
    required List<int> bytes,
    String? contentMimeType,
  }) async {
    final decoded = await _multipartRequest(
      _driveUpdateUri(fileId),
      method: 'PATCH',
      accessToken: accessToken,
      metadata: {'name': name, 'mimeType': mimeType},
      bytes: bytes,
      contentMimeType: contentMimeType ?? mimeType,
      failureMessage: 'Google Drive file update failed',
    );

    return _fileFromJson(decoded, 'Google Drive file update failed');
  }

  Future<GoogleDriveFile> replaceGoogleDocText({
    required String accessToken,
    required String fileId,
    required String name,
    required String text,
  }) async {
    final renamed = await _jsonRequest(
      _driveFileUri(fileId),
      method: 'PATCH',
      accessToken: accessToken,
      body: {'name': name},
      failureMessage: 'Google Docs rename failed',
    );
    final endIndex = await _googleDocEndIndex(
      accessToken: accessToken,
      fileId: fileId,
    );
    final requests = <Map<String, Object?>>[
      if (endIndex > 2)
        {
          'deleteContentRange': {
            'range': {'startIndex': 1, 'endIndex': endIndex - 1},
          },
        },
      if (text.isNotEmpty)
        {
          'insertText': {
            'location': {'index': 1},
            'text': text,
          },
        },
    ];

    await _jsonRequest(
      _googleDocBatchUpdateUri(fileId),
      method: 'POST',
      accessToken: accessToken,
      body: {'requests': requests},
      failureMessage: 'Google Docs body replacement failed',
    );

    return _fileFromJson(renamed, 'Google Docs update failed');
  }

  Future<GoogleDriveFile> moveFile({
    required String accessToken,
    required String fileId,
    required String fromParentId,
    required String toParentId,
  }) async {
    final decoded = await _jsonRequest(
      _driveMoveUri(
        fileId: fileId,
        fromParentId: fromParentId,
        toParentId: toParentId,
      ),
      method: 'PATCH',
      accessToken: accessToken,
      failureMessage: 'Google Drive file move failed',
    );

    return _fileFromJson(decoded, 'Google Drive file move failed');
  }

  Future<void> deleteFile({
    required String accessToken,
    required String fileId,
  }) async {
    await _jsonRequest(
      _driveFileUri(fileId),
      method: 'DELETE',
      accessToken: accessToken,
      failureMessage: 'Google Drive file removal failed',
    );
  }

  Future<String> exportGoogleDocText({
    required String accessToken,
    required String fileId,
  }) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(_driveExportUri(fileId));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );

      final response = await request.close();
      final raw = await utf8.decodeStream(response);
      final status = response.statusCode;

      if (status < 200 || status >= 300) {
        throw StateError(
          _googleApiError(raw) ??
              'Google Docs text export failed with HTTP $status.',
        );
      }

      return raw.trim();
    } on SocketException catch (error) {
      throw StateError(
        'Google Docs text export failed: could not reach Google Drive. '
        '${error.message}',
      );
    } finally {
      client.close();
    }
  }

  Future<List<GoogleDriveFile>> listChildren({
    required String accessToken,
    required String parentId,
  }) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'fields': 'files(id,name,mimeType,webViewLink)',
      'orderBy': 'folder,name',
      'q':
          "'${parentId.replaceAll("'", r"\'")}' in parents and trashed = false",
    });
    final decoded = await _jsonRequest(
      uri,
      method: 'GET',
      accessToken: accessToken,
      failureMessage: 'Google Drive file listing failed',
    );
    final files = decoded['files'];
    if (files is! List) return const [];

    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) => _fileFromJson(item, 'Google Drive file listing failed'))
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

  Uri _driveExportUri(String fileId) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$fileId/export', {
      'mimeType': 'text/plain',
    });
  }

  Uri _googleDocUri(String fileId) {
    return Uri.https('docs.googleapis.com', '/v1/documents/$fileId', {
      'fields': 'body(content(endIndex))',
    });
  }

  Uri _googleDocBatchUpdateUri(String fileId) {
    return Uri.https(
      'docs.googleapis.com',
      '/v1/documents/$fileId:batchUpdate',
    );
  }

  Future<int> _googleDocEndIndex({
    required String accessToken,
    required String fileId,
  }) async {
    final decoded = await _jsonRequest(
      _googleDocUri(fileId),
      method: 'GET',
      accessToken: accessToken,
      failureMessage: 'Google Docs read failed',
    );
    final body = decoded['body'];
    final content = body is Map<String, dynamic> ? body['content'] : null;
    if (content is! List || content.isEmpty) return 1;
    final last = content.last;
    if (last is! Map<String, dynamic>) return 1;

    return last['endIndex'] as int? ?? 1;
  }

  Future<Map<String, dynamic>> _jsonRequest(
    Uri uri, {
    required String method,
    required String accessToken,
    required String failureMessage,
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();

    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );

      if (body != null) {
        final bodyText = jsonEncode(body);
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json; charset=utf-8',
        );
        request.headers.contentLength = utf8.encode(bodyText).length;
        request.write(bodyText);
      }

      return _decodeResponse(await request.close(), failureMessage);
    } on SocketException catch (error) {
      throw StateError(
        '$failureMessage: could not reach Google Drive. ${error.message}',
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _multipartRequest(
    Uri uri, {
    required String method,
    required String accessToken,
    required Map<String, Object?> metadata,
    required List<int> bytes,
    required String contentMimeType,
    required String failureMessage,
  }) async {
    final boundary =
        'support_worker_log_${DateTime.now().microsecondsSinceEpoch}';
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=utf-8\r\n\r\n'
          '${jsonEncode(metadata)}\r\n'
          '--$boundary\r\n'
          'Content-Type: $contentMimeType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final bodyBytes = body.takeBytes();
    final client = HttpClient();

    try {
      final request = await client.openUrl(method, uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(
          HttpHeaders.contentTypeHeader,
          'multipart/related; boundary=$boundary',
        )
        ..contentLength = bodyBytes.length;
      request.add(bodyBytes);

      return _decodeResponse(await request.close(), failureMessage);
    } on SocketException catch (error) {
      throw StateError(
        '$failureMessage: could not reach Google Drive. ${error.message}',
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _decodeResponse(
    HttpClientResponse response,
    String failureMessage,
  ) async {
    final raw = await utf8.decodeStream(response);
    final status = response.statusCode;

    if (status < 200 || status >= 300) {
      throw StateError(
        _googleApiError(raw) ?? '$failureMessage with HTTP $status.',
      );
    }

    if (raw.trim().isEmpty) return const <String, dynamic>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('$failureMessage returned invalid JSON.');
    }

    return decoded;
  }

  GoogleDriveFile _fileFromJson(
    Map<String, dynamic> json,
    String failureMessage,
  ) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final mimeType = json['mimeType'] as String? ?? '';

    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw StateError('$failureMessage: invalid response.');
    }

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
}
