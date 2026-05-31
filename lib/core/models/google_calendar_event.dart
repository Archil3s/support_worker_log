class GoogleCalendarEvent {
  const GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.colorId,
    this.htmlLink,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? colorId;
  final String? htmlLink;
}
