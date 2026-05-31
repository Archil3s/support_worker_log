// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

const _desktopCalendarProxyPort = 51243;

class GoogleCalendarApiPlatform {
  Future<String> insertPrivateEvent({
    required String accessToken,
    required String summary,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
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

    if (_isDesktopLocalApp) {
      _submitDesktopCalendarForm(accessToken: accessToken, event: event);

      return '';
    }

    return _insertDirectGoogleCalendarEvent(
      accessToken: accessToken,
      event: event,
      start: start,
    );
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

  void _submitDesktopCalendarForm({
    required String accessToken,
    required Map<String, Object?> event,
  }) {
    final form = html.FormElement()
      ..method = 'POST'
      ..action = _desktopCalendarProxyUrl
      ..target = '_blank'
      ..style.display = 'none';

    form.children.add(
      html.InputElement(type: 'hidden')
        ..name = 'accessToken'
        ..value = accessToken,
    );
    form.children.add(
      html.InputElement(type: 'hidden')
        ..name = 'event'
        ..value = jsonEncode(event),
    );

    html.document.body?.children.add(form);
    form.submit();
    form.remove();
  }

  Map<String, dynamic> _decodeSuccessfulResponse(html.HttpRequest response) {
    final raw = response.responseText ?? '';
    final status = response.status ?? 0;

    if (status < 200 || status >= 300) {
      throw StateError(
        raw.trim().isEmpty
            ? 'Google Calendar private event creation failed with HTTP $status.'
            : raw,
      );
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('Google Calendar returned an invalid event response.');
    }

    final visibility = decoded['visibility'];

    if (visibility != null && visibility != 'private') {
      throw StateError('Google Calendar did not confirm private visibility.');
    }

    return decoded;
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
