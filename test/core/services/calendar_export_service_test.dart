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
}
