// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

class GoogleDocsApiPlatform {
  Future<Map<String, dynamic>> getDocument({
    required String accessToken,
    required String documentId,
  }) {
    return _jsonRequest(
      _documentUri(documentId, includeTabsContent: true).toString(),
      method: 'GET',
      accessToken: accessToken,
      failureMessage: 'Google Docs document load failed',
    );
  }

  Future<Map<String, dynamic>> batchUpdate({
    required String accessToken,
    required String documentId,
    required List<Map<String, dynamic>> requests,
    String? targetRevisionId,
  }) {
    return _jsonRequest(
      _batchUpdateUri(documentId).toString(),
      method: 'POST',
      accessToken: accessToken,
      body: {
        'requests': requests,
        if (targetRevisionId != null && targetRevisionId.trim().isNotEmpty)
          'writeControl': {'targetRevisionId': targetRevisionId.trim()},
      },
      failureMessage: 'Google Docs update failed',
    );
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String url, {
    required String method,
    required String accessToken,
    required String failureMessage,
    Map<String, dynamic>? body,
  }) async {
    final response = await html.HttpRequest.request(
      url,
      method: method,
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      },
      sendData: body == null ? null : jsonEncode(body),
    );
    final status = response.status ?? 0;
    final raw = response.responseText ?? '';

    if (status < 200 || status >= 300) {
      throw StateError(
        raw.trim().isEmpty ? '$failureMessage with HTTP $status.' : raw,
      );
    }

    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;

    throw StateError('$failureMessage: invalid response.');
  }

  Uri _documentUri(String documentId, {required bool includeTabsContent}) {
    return Uri.https('docs.googleapis.com', '/v1/documents/$documentId', {
      'includeTabsContent': includeTabsContent ? 'true' : 'false',
    });
  }

  Uri _batchUpdateUri(String documentId) {
    return Uri.https(
      'docs.googleapis.com',
      '/v1/documents/$documentId:batchUpdate',
    );
  }
}
