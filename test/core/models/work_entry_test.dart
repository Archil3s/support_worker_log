import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';

void main() {
  test('persists text direction and reply-needed status', () {
    final entry = WorkEntry(
      id: 'entry-1',
      client: 'AB',
      type: EntryType.textNote,
      date: DateTime(2026, 6, 1),
      startTime: const TimeOfDay(hour: 9, minute: 15),
      minutes: 10,
      notes: const ['Check-in'],
      textContactDirection: TextContactDirection.sent,
      textReplyNeeded: true,
    );

    final restored = WorkEntry.fromJson(entry.toJson());

    expect(restored.textContactDirection, TextContactDirection.sent);
    expect(restored.textReplyNeeded, isTrue);
  });

  test('calculates kilometres from home visit odometer readings', () {
    final entry = WorkEntry(
      id: 'entry-2',
      client: 'AB',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 1),
      startTime: const TimeOfDay(hour: 10, minute: 0),
      minutes: 60,
      notes: const [],
      odometerStart: 1280.5,
      odometerEnd: 1294,
    );

    expect(entry.kilometres, 13.5);
  });

  test('calendar event details change when entry time changes', () {
    final entry = WorkEntry(
      id: 'entry-3',
      client: 'AB',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 1),
      startTime: const TimeOfDay(hour: 10, minute: 0),
      minutes: 60,
      notes: const [],
      odometerStart: 100,
      odometerEnd: 112,
      googleCalendarEntered: true,
    );

    final corrected = entry.copyWith(
      startTime: const TimeOfDay(hour: 11, minute: 30),
    );

    expect(entry.hasSameCalendarEventDetails(corrected), isFalse);
  });

  test('calendar event details ignore non-calendar admin fields', () {
    final entry = WorkEntry(
      id: 'entry-4',
      client: 'AB',
      type: EntryType.textNote,
      date: DateTime(2026, 6, 1),
      startTime: const TimeOfDay(hour: 10, minute: 0),
      minutes: 10,
      notes: const ['Check-in'],
      textReplyNeeded: true,
      googleCalendarEntered: true,
    );

    final replied = entry.copyWith(textReplyNeeded: false);

    expect(entry.hasSameCalendarEventDetails(replied), isTrue);
  });
}
