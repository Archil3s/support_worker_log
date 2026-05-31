// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
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
    final decoded = await _listEventsDirectly(
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
      final response = await html.HttpRequest.request(
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
    final response = await html.HttpRequest.request(
      _desktopCalendarProxyUrl,
      method: 'POST',
      requestHeaders: {'Content-Type': 'application/json; charset=utf-8'},
      sendData: jsonEncode({'accessToken': accessToken, 'event': event}),
    );

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

    final response = await html.HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: {'Authorization': 'Bearer $accessToken'},
    );

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
        raw.trim().isEmpty ? '$failureMessage with HTTP $status.' : raw,
      );
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('Google Calendar returned invalid JSON.');
    }

    return decoded;
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
    return '/__google_calendar/private_event';
  }

  String _calendarDayLink(DateTime start) {
    return 'https://calendar.google.com/calendar/u/0/r/day/'
        '${start.year}/${start.month}/${start.day}';
  }
}
