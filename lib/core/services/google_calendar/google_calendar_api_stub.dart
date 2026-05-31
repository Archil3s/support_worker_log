class GoogleCalendarApiPlatform {
  Future<String> insertPrivateEvent({
    required String accessToken,
    required String summary,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) {
    throw UnsupportedError(
      'Direct private Google Calendar creation is only available in the desktop web app.',
    );
  }
}
