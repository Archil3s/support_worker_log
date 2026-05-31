import '../../models/google_calendar_event.dart';

class GoogleCalendarApiPlatform {
  Future<String> insertPrivateEvent({
    required String accessToken,
    required String summary,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
    String? colorId,
  }) {
    throw UnsupportedError(
      'Direct private Google Calendar creation is only available in the desktop web app.',
    );
  }

  Future<List<GoogleCalendarEvent>> listPrimaryEvents({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) {
    throw UnsupportedError(
      'Google Calendar visual sync is only available in the desktop web app.',
    );
  }
}
