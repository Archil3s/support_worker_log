// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
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
    final response = await _request(
      url,
      method: method,
      requestHeaders: {
        'Authorization': 'Bearer $accessToken',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      },
      sendData: body == null ? null : jsonEncode(body),
      failureMessage: failureMessage,
    );

    return _decodeJsonResponse(response, failureMessage: failureMessage);
  }

  Future<html.HttpRequest> _request(
    String url, {
    required String method,
    required Map<String, String> requestHeaders,
    required String failureMessage,
    Object? sendData,
  }) async {
    final completer = Completer<html.HttpRequest>();
    final request = html.HttpRequest()
      ..open(method, url)
      ..timeout = 15000;

    for (final entry in requestHeaders.entries) {
      request.setRequestHeader(entry.key, entry.value);
    }

    request.onLoad.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    });
    request.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            '$failureMessage. The browser could not reach the Google Docs API.',
          ),
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
    final status = response.status ?? 0;
    final raw = response.responseText ?? '';

    if (status < 200 || status >= 300) {
      throw StateError(
        _googleApiError(raw) ??
            (raw.trim().isEmpty ? '$failureMessage with HTTP $status.' : raw),
      );
    }

    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;

    throw StateError('$failureMessage: invalid response.');
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
          return 'Google Docs API error$cleanStatus: ${message.trim()}';
        }
      }
    } catch (_) {
      return null;
    }

    return null;
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
