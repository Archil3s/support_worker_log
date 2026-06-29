import 'dart:convert';
import 'dart:io';

class GoogleDocsApiPlatform {
  Future<Map<String, dynamic>> getDocument({
    required String accessToken,
    required String documentId,
  }) async {
    final decoded = await _jsonRequest(
      _documentUri(documentId, includeTabsContent: true),
      method: 'GET',
      accessToken: accessToken,
      failureMessage: 'Google Docs document load failed',
    );

    return decoded;
  }

  Future<Map<String, dynamic>> batchUpdate({
    required String accessToken,
    required String documentId,
    required List<Map<String, dynamic>> requests,
    String? targetRevisionId,
  }) {
    return _jsonRequest(
      _batchUpdateUri(documentId),
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
    Uri uri, {
    required String method,
    required String accessToken,
    required String failureMessage,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();

    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final raw = await utf8.decodeStream(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          raw.trim().isEmpty
              ? '$failureMessage with HTTP ${response.statusCode}.'
              : raw,
        );
      }

      if (raw.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;

      throw StateError('$failureMessage: invalid response.');
    } on SocketException catch (error) {
      throw StateError('$failureMessage: ${error.message}');
    } finally {
      client.close(force: true);
    }
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
