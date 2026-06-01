// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../../models/google_calendar_event.dart';

const _desktopCalendarProxyPort = 51243;

class GoogleCalendarApiPlatform {
  Future<String> insertPrivateEvent({
    required String accessToken,
    required String summary,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
    String? colorId,
  }) async {
    final event = <String, Object?>{
      'summary': summary,
      'description': description,
      'location': location,
      'start': {'dateTime': start.toUtc().toIso8601String()},
      'end': {'dateTime': end.toUtc().toIso8601String()},
      'visibility': 'private',
      'transparency': 'opaque',
      'extendedProperties': {
        'private': {'createdBy': 'support_worker_log'},
      },
    };

    if (colorId != null && colorId.trim().isNotEmpty) {
      event['colorId'] = colorId;
    }

    if (_isDesktopLocalApp) {
      return _insertViaDesktopProxy(accessToken: accessToken, event: event);
    }

    return _insertDirectGoogleCalendarEvent(
      accessToken: accessToken,
      event: event,
      start: start,
    );
  }

  Future<List<GoogleCalendarEvent>> listPrimaryEvents({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async {
    final decoded = _isDesktopLocalApp
        ? await _listEventsViaDesktopProxy(
            accessToken: accessToken,
            start: start,
            end: end,
          )
        : await _listEventsDirectly(
            accessToken: accessToken,
            start: start,
            end: end,
          );

    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_eventFromJson)
        .whereType<GoogleCalendarEvent>()
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<String> _insertDirectGoogleCalendarEvent({
    required String accessToken,
    required Map<String, Object?> event,
    required DateTime start,
  }) async {
    try {
      final response = await _sendRequest(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        method: 'POST',
        requestHeaders: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=utf-8',
        },
        sendData: jsonEncode(event),
      );

      final decoded = _decodeSuccessfulResponse(response);
      final htmlLink = decoded['htmlLink'];

      if (htmlLink is String && htmlLink.trim().isNotEmpty) {
        return htmlLink;
      }

      return _calendarDayLink(start);
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }

      throw StateError('Could not reach Google Calendar. Try again shortly.');
    }
  }

  Future<String> _insertViaDesktopProxy({
    required String accessToken,
    required Map<String, Object?> event,
  }) async {
    late final html.HttpRequest response;

    try {
      response = await _sendRequest(
        _desktopCalendarProxyUrl,
        method: 'POST',
        requestHeaders: {'Content-Type': 'text/plain;charset=UTF-8'},
        sendData: jsonEncode({'accessToken': accessToken, 'event': event}),
      );
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('Could not reach the desktop Google Calendar proxy.');
    }

    final decoded = _decodeSuccessfulResponse(response);
    final htmlLink = decoded['htmlLink'];

    return htmlLink is String ? htmlLink : '';
  }

  Future<Map<String, dynamic>> _listEventsDirectly({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async {
    final params = {
      'singleEvents': 'true',
      'orderBy': 'startTime',
      'timeMin': start.toUtc().toIso8601String(),
      'timeMax': end.toUtc().toIso8601String(),
    };
    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/primary/events',
      params,
    );

    late final html.HttpRequest response;

    try {
      response = await _sendRequest(
        uri.toString(),
        method: 'GET',
        requestHeaders: {'Authorization': 'Bearer $accessToken'},
      );
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('Could not load Google Calendar events.');
    }

    return _decodeJsonResponse(
      response,
      failureMessage: 'Google Calendar events fetch failed',
    );
  }

  Future<Map<String, dynamic>> _listEventsViaDesktopProxy({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async {
    late final html.HttpRequest response;

    try {
      response = await _sendRequest(
        _desktopCalendarEventsProxyUrl,
        method: 'POST',
        requestHeaders: {'Content-Type': 'text/plain;charset=UTF-8'},
        sendData: jsonEncode({
          'accessToken': accessToken,
          'timeMin': start.toUtc().toIso8601String(),
          'timeMax': end.toUtc().toIso8601String(),
        }),
      );
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('Could not reach the desktop Google Calendar proxy.');
    }

    return _decodeJsonResponse(
      response,
      failureMessage: 'Google Calendar events fetch failed',
    );
  }

  Map<String, dynamic> _decodeSuccessfulResponse(html.HttpRequest response) {
    final decoded = _decodeJsonResponse(
      response,
      failureMessage: 'Google Calendar private event creation failed',
    );

    final visibility = decoded['visibility'];

    if (visibility != null && visibility != 'private') {
      throw StateError('Google Calendar did not confirm private visibility.');
    }

    return decoded;
  }

  Map<String, dynamic> _decodeJsonResponse(
    html.HttpRequest response, {
    required String failureMessage,
  }) {
    final raw = response.responseText ?? '';
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      throw StateError(
        _failureText(raw: raw, fallback: '$failureMessage with HTTP $status.'),
      );
    }

    return _decodeJson(raw);
  }

  Future<html.HttpRequest> _sendRequest(
    String url, {
    required String method,
    Map<String, String>? requestHeaders,
    Object? sendData,
  }) {
    final completer = Completer<html.HttpRequest>();
    final request = html.HttpRequest()
      ..open(method, url)
      ..timeout = 15000;

    for (final entry in (requestHeaders ?? const <String, String>{}).entries) {
      request.setRequestHeader(entry.key, entry.value);
    }

    request.onLoad.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    });
    request.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Network request failed.'));
      }
    });
    request.onTimeout.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Network request timed out.'));
      }
    });

    request.send(sendData);

    return completer.future;
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        throw StateError('Google Calendar returned invalid JSON.');
      }

      return decoded;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('Google Calendar returned invalid JSON.');
    }
  }

  String _failureText({required String raw, required String fallback}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;

    try {
      final decoded = jsonDecode(trimmed);

      if (decoded is Map) {
        final error = decoded['error'];

        if (error is Map) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      return trimmed;
    }

    return trimmed;
  }

  GoogleCalendarEvent? _eventFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final summary = json['summary'] as String? ?? '(No title)';
    final start = _dateTimeFromEventEndpoint(json['start']);
    final end = _dateTimeFromEventEndpoint(json['end']);

    if (id.trim().isEmpty || start == null || end == null) {
      return null;
    }

    return GoogleCalendarEvent(
      id: id,
      title: summary,
      start: start.toLocal(),
      end: end.toLocal(),
      colorId: json['colorId'] as String?,
      htmlLink: json['htmlLink'] as String?,
    );
  }

  DateTime? _dateTimeFromEventEndpoint(Object? value) {
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    final dateTime = map['dateTime'] as String?;

    if (dateTime != null && dateTime.trim().isNotEmpty) {
      return DateTime.tryParse(dateTime);
    }

    final date = map['date'] as String?;
    if (date == null || date.trim().isEmpty) return null;

    return DateTime.tryParse(date);
  }

  bool get _isDesktopLocalApp {
    final uri = html.window.location;
    final hostname = uri.hostname;
    final port = uri.port;

    return (hostname == 'localhost' || hostname == '127.0.0.1') &&
        port == '$_desktopCalendarProxyPort';
  }

  String get _desktopCalendarProxyUrl {
    return '$_desktopCalendarProxyOrigin/__google_calendar/private_event';
  }

  String get _desktopCalendarEventsProxyUrl {
    return '$_desktopCalendarProxyOrigin/__google_calendar/events';
  }

  String get _desktopCalendarProxyOrigin {
    final location = html.window.location;

    if (location.hostname == '127.0.0.1') {
      return 'http://localhost:$_desktopCalendarProxyPort';
    }

    return location.origin;
  }

  String _calendarDayLink(DateTime start) {
    return 'https://calendar.google.com/calendar/u/0/r/day/'
        '${start.year}/${start.month}/${start.day}';
  }
}
