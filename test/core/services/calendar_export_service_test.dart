import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/calendar_export_service.dart';

void main() {
  test('ICS export marks entries as private busy calendar events', () {
    final entry = WorkEntry(
      id: 'entry-1',
      client: 'AB',
      type: EntryType.homeVisit,
      date: DateTime(2026, 5, 31),
      startTime: const TimeOfDay(hour: 9, minute: 30),
      minutes: 90,
      notes: const ['Medication prompt'],
      supportNoteBreakdown: 'Outcome(s)\n1. Supported morning routine.',
    );

    final ics = CalendarExportService.buildIcsForEntry(entry);

    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('SUMMARY:AB Home Visit'));
    expect(ics, contains('CLASS:PRIVATE'));
    expect(ics, contains('TRANSP:OPAQUE'));
    expect(ics, contains('X-MICROSOFT-CDO-BUSYSTATUS:BUSY'));
    expect(ics, contains('END:VEVENT'));
  });

  test('ICS export keeps support notes out of the calendar description', () {
    final entry = WorkEntry(
      id: 'entry-4',
      client: 'EF',
      type: EntryType.homeVisit,
      date: DateTime(2026, 5, 31),
      startTime: const TimeOfDay(hour: 10, minute: 0),
      minutes: 45,
      notes: const ['Sensitive topic'],
      supportNoteBreakdown: 'Outcome(s)\nSensitive support detail.',
      odometerStart: 100,
      odometerEnd: 112.5,
    );

    final ics = CalendarExportService.buildIcsForEntry(entry);

    expect(ics, contains('Visit duration: 45 minutes'));
    expect(ics, contains('Billable time:'));
    expect(ics, contains('Kilometres travelled: 12.5 km'));
    expect(ics, isNot(contains('Sensitive topic')));
    expect(ics, isNot(contains('Sensitive support detail')));
    expect(ics, isNot(contains('Notes / topics')));
  });

  test('ICS export escapes text fields for calendar imports', () {
    final entry = WorkEntry(
      id: 'entry,2',
      client: 'A;B',
      type: EntryType.phoneCall,
      date: DateTime(2026, 5, 31),
      startTime: const TimeOfDay(hour: 14, minute: 0),
      minutes: 30,
      notes: const ['Call, update'],
    );

    final ics = CalendarExportService.buildIcsForEntry(entry);

    expect(ics, contains(r'UID:entry\,2@support-worker-log'));
    expect(ics, contains(r'LOCATION:A\;B'));
  });

  test('important text notes export with important color and title', () {
    final entry = WorkEntry(
      id: 'entry-3',
      client: 'CD',
      type: EntryType.textNote,
      date: DateTime(2026, 5, 31),
      startTime: const TimeOfDay(hour: 15, minute: 0),
      minutes: 20,
      notes: const ['Text update'],
      importantText: true,
    );

    final ics = CalendarExportService.buildIcsForEntry(entry);

    expect(ics, contains('SUMMARY:IMPORTANT TEXT CD'));
    expect(ics, contains('COLOR:#D50000'));
  });

  test('Google Calendar draft URL uses safe visit details without notes', () {
    final entry = WorkEntry(
      id: 'entry-5',
      client: 'GH',
      type: EntryType.homeVisit,
      date: DateTime(2026, 5, 31),
      startTime: const TimeOfDay(hour: 12, minute: 30),
      minutes: 60,
      notes: const ['Sensitive topic'],
      supportNoteBreakdown: 'Outcome(s)\nPrivate support note.',
    );

    final uri = CalendarExportService.googleCalendarDraftUriForEntry(entry);

    expect(uri.host, 'calendar.google.com');
    expect(uri.path, '/calendar/render');
    expect(uri.queryParameters['action'], 'TEMPLATE');
    expect(uri.queryParameters['text'], 'GH Home Visit');
    expect(uri.queryParameters['dates'], contains('/'));
    expect(uri.queryParameters['details'], contains('Visit duration: 60'));
    expect(uri.queryParameters['details'], isNot(contains('Sensitive topic')));
    expect(uri.queryParameters['details'], isNot(contains('Private support')));
  });
}
