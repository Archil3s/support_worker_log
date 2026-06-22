import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/local_support_note_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PAYE draft saves in app without folder or typed initials', () async {
    final entry = WorkEntry(
      id: 'paye-note-1',
      client: 'Jane Smith',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 19),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );

    final saved = await LocalSupportNoteService.saveDraftMeta(
      entry: entry,
      initials: '',
      status: EntrySupportNoteStatus.finished,
      noteText: 'Attendance: Jane and support worker.',
    );
    final restored = await LocalSupportNoteService.loadMeta(entry.id);

    expect(saved.initials, 'JS');
    expect(restored?.noteText, 'Attendance: Jane and support worker.');
    expect(restored?.status, EntrySupportNoteStatus.finished);
  });

  test('PAYE draft keeps long note text without word limit trimming', () async {
    final entry = WorkEntry(
      id: 'paye-note-long',
      client: 'Jane Smith',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 19),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );
    final longNote = List.generate(
      260,
      (index) => 'line ${index + 1}: detailed PAYE session note',
    ).join('\n');

    await LocalSupportNoteService.saveDraftMeta(
      entry: entry,
      initials: '',
      status: EntrySupportNoteStatus.finished,
      noteText: longNote,
    );

    final restored = await LocalSupportNoteService.loadMeta(entry.id);

    expect(restored?.noteText, longNote);
  });

  test('removeMeta deletes stored support note metadata', () async {
    final entry = WorkEntry(
      id: 'paye-note-remove',
      client: 'Jane Smith',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 19),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );

    await LocalSupportNoteService.saveDraftMeta(
      entry: entry,
      initials: '',
      status: EntrySupportNoteStatus.finished,
      noteText: 'Next step\nCall back tomorrow.',
    );

    await LocalSupportNoteService.removeMeta(entry.id);

    expect(await LocalSupportNoteService.loadMeta(entry.id), isNull);
  });
}
