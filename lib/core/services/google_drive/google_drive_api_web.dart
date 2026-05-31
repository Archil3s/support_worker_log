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

    final response = await html.HttpRequest.request(
      _driveFilesUri.toString(),
      method: 'POST',
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=utf-8',
      },
      sendData: jsonEncode(body),
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

    final response = await html.HttpRequest.request(
      _driveUploadUri.toString(),
      method: 'POST',
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      sendData: body.takeBytes(),
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

    final response = await html.HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
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

  Map<String, dynamic> _decodeJsonResponse(
    html.HttpRequest response, {
    required String failureMessage,
  }) {
    final raw = response.responseText ?? '';
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      throw StateError(
        raw.trim().isEmpty ? '$failureMessage with HTTP $status.' : raw,
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
}
