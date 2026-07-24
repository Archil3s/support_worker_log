import 'dart:convert';

import 'package:archive/archive.dart';
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

    expect(saved.initials, 'Jane Smith');
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

  test('Work draft keeps long support note text without trimming', () async {
    final entry = WorkEntry(
      id: 'work-note-long',
      client: 'Jane Smith',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 19),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );
    final longNote = [
      'Main topic(s)',
      List.generate(
        260,
        (index) => 'line ${index + 1}: detailed Work support note',
      ).join('\n'),
      '',
      'Outcome(s)',
      'Stored successfully.',
      '',
      'Next action(s)',
      'None.',
      '',
      'Overall impression',
      'Factual Work note retained in the normal support note format.',
      '',
      'Referrals',
      'No referrals discussed or made this visit.',
      '',
      'Safety concerns for sexual harm survivors and mental health',
      'No safety concerns noted.',
    ].join('\n');

    await LocalSupportNoteService.saveDraftMeta(
      entry: entry,
      initials: '',
      status: EntrySupportNoteStatus.finished,
      noteText: longNote,
    );

    final restored = await LocalSupportNoteService.loadMeta(entry.id);

    expect(restored?.noteText, longNote);
  });

  test('canonical support note text keeps one spacing rule', () {
    final canonical = LocalSupportNoteService.canonicalSupportNoteText(
      'Outcome(s)\nSorted out transport\n'
      'Main topic(s)\nAppointment planning\n\n'
      'Referrals\nNo referrals discussed or made this visit.',
    );

    expect(
      canonical,
      [
        'Main topic(s)',
        'Appointment planning',
        '',
        'Outcome(s)',
        'Sorted out transport',
        '',
        'Next action(s)',
        '',
        'Overall impression',
        '',
        'Referrals',
        'No referrals discussed or made this visit.',
        '',
        'Safety concerns for sexual harm survivors and mental health',
      ].join('\n'),
    );
  });

  test('support note template does not count as entered content', () {
    expect(
      LocalSupportNoteService.hasEnteredSupportNoteContent(
        supportNoteBreakdownTemplate,
      ),
      isFalse,
    );
  });

  test('support note content detector ignores default support checks', () {
    final noteText = [
      'Main topic(s)',
      '',
      'Referrals',
      'No referrals discussed or made this visit.',
      '',
      'Safety concerns for sexual harm survivors and mental health',
      'No safety concerns noted.',
    ].join('\n');

    expect(
      LocalSupportNoteService.hasEnteredSupportNoteContent(noteText),
      isFalse,
    );
  });

  test('support note content detector accepts typed section content', () {
    expect(
      LocalSupportNoteService.hasEnteredSupportNoteContent(
        'Main topic(s)\nSorted transport to appointment.',
      ),
      isTrue,
    );
  });

  test('blank PAYE-style headings do not count as entered content', () {
    final noteText = [
      'Attendance',
      '',
      'What happened',
      '',
      'Work/task completed',
      '',
      'Support given',
      '',
      'Issue/problem',
      '',
      'Outcome',
      '',
      'Next step',
      '',
      'Anything to follow up',
      '',
      'Referrals',
    ].join('\n');

    expect(
      LocalSupportNoteService.hasEnteredSupportNoteContent(noteText),
      isFalse,
    );
  });

  test('PAYE-style outcome content counts as entered content', () {
    expect(
      LocalSupportNoteService.hasEnteredSupportNoteContent(
        'Outcome\nConsent form was given.',
      ),
      isTrue,
    );
  });

  test('empty Work draft still saves in app', () async {
    final entry = WorkEntry(
      id: 'work-note-empty',
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
      status: EntrySupportNoteStatus.inProgress,
      noteText: '',
    );

    final restored = await LocalSupportNoteService.loadMeta(entry.id);

    expect(restored?.initials, 'Jane Smith');
    expect(restored?.noteText, '');
    expect(restored?.status, EntrySupportNoteStatus.inProgress);
  });

  test('support note title uses the app client name, not initials', () {
    final entry = WorkEntry(
      id: 'work-note-title',
      client: 'Brad Roberts',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 26),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );

    final title = LocalSupportNoteService.noteTitle(
      entry: entry,
      initials: 'BR',
      status: EntrySupportNoteStatus.incomplete,
    );

    expect(title, 'Brad Roberts | 26/06/2026 | Incomplete');
  });

  test('support note title prefers full saved name over initials code', () {
    final entry = WorkEntry(
      id: 'work-note-title-code',
      client: 'BR',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 26),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );

    final title = LocalSupportNoteService.noteTitle(
      entry: entry,
      initials: 'Brad Roberts',
      status: EntrySupportNoteStatus.submitted,
    );

    expect(title, 'Brad Roberts | 26/06/2026 | Submitted');
  });

  test('support note title expands initials code to a single saved name', () {
    final entry = WorkEntry(
      id: 'work-note-title-single-name',
      client: 'BR',
      type: EntryType.homeVisit,
      date: DateTime(2026, 6, 26),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 60,
      notes: const [],
    );

    final title = LocalSupportNoteService.noteTitle(
      entry: entry,
      initials: 'Brad',
      status: EntrySupportNoteStatus.incomplete,
    );

    expect(title, 'Brad | 26/06/2026 | Incomplete');
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

  test('reads current text from a Word document', () {
    final archive = Archive();
    final documentBytes = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:document xmlns:w="word">'
      '<w:body>'
      '<w:p><w:r><w:t>What happened</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>Current Word edit &amp; follow-up.</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>Outcome</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>Updated in Word.</w:t></w:r></w:p>'
      '</w:body>'
      '</w:document>',
    );
    archive.addFile(
      ArchiveFile('word/document.xml', documentBytes.length, documentBytes),
    );
    final bytes = ZipEncoder().encode(archive)!;

    expect(
      LocalSupportNoteService.wordDocumentText(bytes),
      [
        'What happened',
        'Current Word edit & follow-up.',
        'Outcome',
        'Updated in Word.',
      ].join('\n'),
    );
  });

  test('support note metadata keeps its document update time', () {
    final updatedAt = DateTime.utc(2026, 7, 24, 3, 15);
    final meta = EntrySupportNoteMeta(
      entryId: 'word-meta',
      initials: 'Jane Smith',
      status: EntrySupportNoteStatus.inProgress,
      fileName: 'Jane Smith/current.docx',
      noteText: 'Current document text',
      updatedAt: updatedAt,
    );

    final restored = EntrySupportNoteMeta.fromJson(meta.toJson());

    expect(restored.updatedAt, updatedAt);
  });
}
