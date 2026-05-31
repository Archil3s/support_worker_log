import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/entry_type.dart';
import '../models/work_entry.dart';
import 'google_calendar/google_calendar_api_platform.dart';

const _defaultCalendarColor = '#FF0000';

class CalendarExportService {
  const CalendarExportService._();

  static final GoogleCalendarApiPlatform _googleCalendarApi =
      GoogleCalendarApiPlatform();

  static Future<bool> createPrivateGoogleCalendarEventForEntry(
    WorkEntry entry, {
    required String accessToken,
  }) async {
    final start = _entryStart(entry);
    final end = _entryEnd(entry);
    final link = await _googleCalendarApi.insertPrivateEvent(
      accessToken: accessToken,
      summary: '${entry.client} ${entry.type.label}',
      description: _detailsForEntry(entry, start, end),
      location: entry.client,
      start: start,
      end: end,
    );

    if (link.trim().isEmpty) {
      return true;
    }

    return launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  static Future<void> saveIcsFileForEntry(WorkEntry entry) async {
    final start = _entryStart(entry);
    final ics = buildIcsForEntry(entry);
    final bytes = Uint8List.fromList(utf8.encode(ics));

    final fileName = _safeFileName(
      '${entry.client}_${_fileDate(start)}_${entry.type.label}_calendar',
    );

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'ics',
      mimeType: MimeType.text,
    );
  }

  static String buildIcsForEntry(WorkEntry entry) {
    final start = _entryStart(entry);
    final end = _entryEnd(entry);
    final now = DateTime.now().toUtc();

    final title = '${entry.client} ${entry.type.label}';
    final details = _detailsForEntry(entry, start, end);

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Support Worker Log//Entries//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${_icsEscape('${entry.id}@support-worker-log')}',
      'DTSTAMP:${_icsDate(now)}',
      'DTSTART:${_icsDate(start.toUtc())}',
      'DTEND:${_icsDate(end.toUtc())}',
      'SUMMARY:${_icsEscape(title)}',
      'DESCRIPTION:${_icsEscape(details)}',
      'LOCATION:${_icsEscape(entry.client)}',
      'CLASS:PRIVATE',
      'TRANSP:OPAQUE',
      'COLOR:$_defaultCalendarColor',
      'X-APPLE-CALENDAR-COLOR:$_defaultCalendarColor',
      'X-MICROSOFT-CDO-BUSYSTATUS:BUSY',
      'CATEGORIES:${_icsEscape(entry.client)}',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }

  static DateTime _entryStart(WorkEntry entry) {
    return DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
      entry.startTime.hour,
      entry.startTime.minute,
    );
  }

  static DateTime _entryEnd(WorkEntry entry) {
    return _entryStart(
      entry,
    ).add(Duration(minutes: entry.minutes.clamp(1, 1440).toInt()));
  }

  static String _detailsForEntry(
    WorkEntry entry,
    DateTime start,
    DateTime end,
  ) {
    final breakdown = entry.supportNoteBreakdown.trim().isEmpty
        ? supportNoteBreakdownTemplate.trim()
        : entry.supportNoteBreakdown.trim();

    final buffer = StringBuffer()
      ..writeln(_sentenceForEntry(entry, start, end))
      ..writeln()
      ..writeln(breakdown)
      ..writeln()
      ..writeln('Client initials: ${entry.client}')
      ..writeln('Support type: ${entry.type.label}')
      ..writeln('Date: ${_formatDate(entry.date)}')
      ..writeln('Start time: ${_formatClock(start)}')
      ..writeln('End time: ${_formatClock(end)}')
      ..writeln(
        'Duration: ${entry.minutes} minutes (${entry.hours.toStringAsFixed(2)} hours)',
      );

    if (entry.kilometres > 0) {
      buffer.writeln('Kilometres: ${entry.kilometres.toStringAsFixed(1)} km');
    }

    if (entry.notes.isNotEmpty) {
      final sortedNotes = entry.notes.toList()..sort();

      buffer
        ..writeln()
        ..writeln('Quick notes:');

      for (final note in sortedNotes) {
        buffer.writeln('- $note');
      }
    }

    if (entry.nextActions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Next actions:');

      for (final item in entry.nextActions) {
        final completed = item.completedAt == null
            ? ''
            : ' (completed ${_formatDate(item.completedAt!)} '
                  '${_formatClock(item.completedAt!)})';

        buffer.writeln('- ${item.text}$completed');
      }
    }

    return buffer.toString().trim();
  }

  static String _sentenceForEntry(
    WorkEntry entry,
    DateTime start,
    DateTime end,
  ) {
    return '${entry.client} ${entry.type.label} on ${_formatDate(entry.date)} '
        'from ${_formatClock(start)} to ${_formatClock(end)} '
        'for ${entry.minutes} minutes (${entry.hours.toStringAsFixed(2)} hours).';
  }

  static String _icsDate(DateTime value) {
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

  static String _formatDate(DateTime value) {
    return '${_two(value.day)}/${_two(value.month)}/${value.year}';
  }

  static String _formatClock(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  static String _fileDate(DateTime value) {
    return '${value.year}${_two(value.month)}${_two(value.day)}';
  }

  static String _safeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  static String _icsEscape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
