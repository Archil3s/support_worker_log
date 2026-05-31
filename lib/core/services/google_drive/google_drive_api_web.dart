// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import '../../models/google_drive_file.dart';

class GoogleDriveApiPlatform {
  Future<GoogleDriveFile> createFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) async {
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
  }) async {
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
          'Content-Type: $mimeType\r\n\r\n',
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

  Future<List<GoogleDriveFile>> listChildren({
    required String accessToken,
    required String parentId,
  }) async {
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
  }) async {
    try {
      return await html.HttpRequest.request(
        url,
        method: method,
        requestHeaders: requestHeaders,
        sendData: sendData,
      );
    } catch (error) {
      if (error is html.ProgressEvent) {
        throw StateError(
          '$failureMessage. The browser could not reach the Google Drive API. '
          'Check that Google Drive API is enabled for this Firebase/Google project.',
        );
      }

      throw StateError('$failureMessage: ${_readableError(error)}');
    }
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

  String _readableError(Object error) {
    final text = error.toString();
    if (!text.startsWith('Instance of ')) return text;

    return 'Google returned an unreadable browser error. Reconnect Drive and try again. If it repeats, enable Google Drive API in the Google Cloud project used by Firebase.';
  }
}
