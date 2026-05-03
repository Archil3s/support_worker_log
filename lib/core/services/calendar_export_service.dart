import 'package:url_launcher/url_launcher.dart';

import '../models/entry_type.dart';
import '../models/work_entry.dart';

class CalendarExportService {
  const CalendarExportService._();

  static Future<bool> openGoogleCalendarForEntry(WorkEntry entry) async {
    final start = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
      entry.startTime.hour,
      entry.startTime.minute,
    );

    final end = start.add(
      Duration(minutes: entry.minutes.clamp(1, 1440).toInt()),
    );

    final title = '${entry.client} - ${entry.type.label}';

    final details = StringBuffer()
      ..writeln('Client: ${entry.client}')
      ..writeln('Type: ${entry.type.label}')
      ..writeln('Duration: ${entry.minutes} minutes');

    if (entry.kilometres > 0) {
      details.writeln('Kilometres: ${entry.kilometres.toStringAsFixed(1)} km');
    }

    if (entry.notes.isNotEmpty) {
      details.writeln('');
      details.writeln('Notes:');
      for (final note in entry.notes) {
        details.writeln('- $note');
      }
    }

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_googleCalendarDate(start)}/${_googleCalendarDate(end)}',
      'details': details.toString().trim(),
      'location': entry.client,
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _googleCalendarDate(DateTime value) {
    final utc = value.toUtc();

    return '${utc.year}'
        '${_two(utc.month)}'
        '${_two(utc.day)}'
        'T'
        '${_two(utc.hour)}'
        '${_two(utc.minute)}'
        '${_two(utc.second)}'
        'Z';
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
