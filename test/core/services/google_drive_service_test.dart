import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/constants/personal_log_metrics.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/google_drive_file.dart';
import 'package:support_worker_log/core/models/personal_log_entry.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/google_drive/google_drive_api_platform.dart';
import 'package:support_worker_log/core/services/google_drive_service.dart';
import 'package:support_worker_log/core/services/local_support_note_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uploadDefaultTemplates updates existing Drive templates', () async {
    final api = _FakeGoogleDriveApi(
      children: [
        const GoogleDriveFile(
          id: 'template-docx',
          name: 'TEMPLATE.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
        const GoogleDriveFile(
          id: 'support-note-template',
          name: 'Structured Support Note Template.txt',
          mimeType: 'text/plain',
        ),
      ],
    );
    final service = GoogleDriveService(api: api);

    final uploads = await service.uploadDefaultTemplates(
      accessToken: 'token',
      templatesFolderId: 'templates',
    );

    expect(uploads.map((upload) => upload.name), contains('TEMPLATE.docx'));
    expect(api.uploadedNames, isNot(contains('TEMPLATE.docx')));
    expect(api.updatedFileIds, contains('template-docx'));
    expect(api.updatedFileIds, contains('support-note-template'));
  });

  test(
    'saveSupportNote uploads template docx content as a Google Doc',
    () async {
      final api = _FakeGoogleDriveApi(children: const []);
      final service = GoogleDriveService(api: api);

      final meta = await service.saveSupportNote(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'Jane Smith',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ),
        initials: 'AB',
        status: EntrySupportNoteStatus.inProgress,
        noteText:
            'Main topic(s)\nTest note\n\nSecond paragraph\n\n'
            'Outcome(s)\nSaved to Drive\n\n'
            'Next action(s)\nFollow up tomorrow\n\n'
            'Overall impression\nSettled\n\n'
            'Referrals\n'
            'No referrals discussed or made this visit.\n\n'
            'Safety concerns for sexual harm survivors and mental health\n'
            'No safety concerns noted.',
      );

      final noteUpload = api.uploads.singleWhere(
        (upload) => upload.name == '2026-06-02_Jane_Smith_in-progress',
      );
      final documentXml = _docxXml(noteUpload.bytes);
      final documentText = _docxText(noteUpload.bytes);
      final paragraphs = _docxParagraphTexts(noteUpload.bytes);
      final mainLine = paragraphs.indexOf('Test note');
      final secondLine = paragraphs.indexOf('Second paragraph');

      expect(meta.fileName, '2026-06-02_Jane_Smith_in-progress');
      expect(meta.mimeType, _googleDocsMimeType);
      expect(meta.openLink, 'https://docs.google.com/document/d/new-doc/edit');
      expect(
        meta.folderOpenLink,
        startsWith('https://drive.google.com/drive/folders/'),
      );
      expect(
        meta.folderOpenLink,
        contains('client-notes%2FJane%20Smith%2FInvoice%2010'),
      );
      expect(meta.folderOpenLink, contains('Home%20Visits'));
      expect(noteUpload.parentId, contains('client-notes/Jane Smith'));
      expect(noteUpload.mimeType, _googleDocsMimeType);
      expect(noteUpload.contentMimeType, _docxMimeType);
      expect(noteUpload.parentId, contains('/Home Visits'));
      expect(documentText, contains('Name of client: Jane Smith'));
      expect(documentText, contains('Interaction: Home Visit'));
      expect(documentText, isNot(contains('Date/time/length')));
      expect(documentText, isNot(contains('9:00')));
      expect(documentText, isNot(contains('60 minutes')));
      expect(documentText, isNot(contains('1.00 hours')));
      expect(documentText, isNot(contains('Kilometres')));
      expect(documentText, contains('Main topic(s)'));
      expect(documentText, contains('Test note'));
      expect(mainLine, isNonNegative);
      expect(secondLine, greaterThan(mainLine));
      expect(paragraphs.sublist(mainLine + 1, secondLine), contains(''));
      expect(documentText, contains('Outcome(s)'));
      expect(documentText, contains('Saved to Drive'));
      expect(documentText, contains('Next actions'));
      expect(documentText, contains('Follow up tomorrow'));
      expect(documentText, contains('Settled'));
      expect(
        documentText.indexOf('Referrals'),
        greaterThan(documentText.indexOf('Follow up tomorrow')),
      );
      expect(
        documentText.indexOf(
          'Safety concerns for sexual harm survivors and mental health',
        ),
        greaterThan(documentText.indexOf('No referrals discussed')),
      );
      expect(_paragraphHasBoldText(documentXml, 'Referrals'), true);
      expect(
        _paragraphHasBoldText(
          documentXml,
          'Safety concerns for sexual harm survivors and mental health',
        ),
        true,
      );
    },
  );

  test('saveSupportNote prefers full name over initials code', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    await service.saveSupportNote(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-full-name',
        client: 'BR',
        type: EntryType.homeVisit,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 60,
        notes: const [],
      ),
      initials: 'Brad Roberts',
      status: EntrySupportNoteStatus.submitted,
      noteText: 'Main topic(s)\nFull name shown.',
    );

    final noteUpload = api.uploads.singleWhere(
      (upload) => upload.name == '2026-06-02_Brad_Roberts_submitted',
    );
    final documentText = _docxText(noteUpload.bytes);

    expect(noteUpload.parentId, contains('client-notes/Brad Roberts'));
    expect(documentText, contains('Name of client: Brad Roberts'));
    expect(documentText, isNot(contains('Name of client: BR')));
  });

  test(
    'findSupportNoteInDrive prefers Google Docs from current folder',
    () async {
      final api = _FakeGoogleDriveApi(
        childrenByParent: {
          'client-notes': [
            const GoogleDriveFile(
              id: 'client-folder',
              name: 'AB',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'client-folder': [
            const GoogleDriveFile(
              id: 'period-folder',
              name: 'Invoice 10 - 2026-05-31 to 2026-06-13',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'period-folder': [
            const GoogleDriveFile(
              id: 'type-folder',
              name: 'Home Visits',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'type-folder': [
            const GoogleDriveFile(
              id: 'google-doc-note',
              name: '2026-06-02_AB_finished.docx',
              mimeType: _googleDocsMimeType,
              webViewLink: 'https://docs.example/note',
            ),
            const GoogleDriveFile(
              id: 'drive-note',
              name: '2026-06-02_AB_finished.docx',
              mimeType: _docxMimeType,
              webViewLink: 'https://drive.example/note',
            ),
          ],
        },
      );
      final service = GoogleDriveService(api: api);

      final meta = await service.findSupportNoteInDrive(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ),
        googleAccountEmail: 'work@example.com',
      );

      expect(meta, isNotNull);
      expect(meta!.fileId, 'google-doc-note');
      expect(meta.fileName, '2026-06-02_AB_finished.docx');
      expect(meta.status, EntrySupportNoteStatus.finished);
      expect(meta.parentFolderId, 'type-folder');
      expect(meta.openLink, 'https://docs.example/note');
      expect(meta.googleAccountEmail, 'work@example.com');
    },
  );

  test('findPayeNoteInDrive returns existing PAYE docx', () async {
    final api = _FakeGoogleDriveApi(
      childrenByParent: {
        'paye-notes': [
          const GoogleDriveFile(
            id: 'person-folder',
            name: 'Jane Smith',
            mimeType: 'application/vnd.google-apps.folder',
          ),
        ],
        'person-folder': [
          const GoogleDriveFile(
            id: 'year-folder',
            name: '2026',
            mimeType: 'application/vnd.google-apps.folder',
          ),
        ],
        'year-folder': [
          const GoogleDriveFile(
            id: 'paye-note',
            name: '2026-06-07_Jane_Smith.docx',
            mimeType: _docxMimeType,
            webViewLink: 'https://drive.example/paye-note',
          ),
        ],
      },
    );
    final service = GoogleDriveService(api: api);

    final meta = await service.findPayeNoteInDrive(
      accessToken: 'token',
      notesFolderId: 'paye-notes',
      entry: WorkEntry(
        id: 'paye-1',
        client: 'Jane Smith',
        type: EntryType.homeVisit,
        date: DateTime(2026, 6, 7),
        startTime: const TimeOfDay(hour: 10, minute: 30),
        minutes: 30,
        notes: const [],
      ),
      googleAccountEmail: 'paye@example.com',
    );

    expect(meta, isNotNull);
    expect(meta!.fileId, 'paye-note');
    expect(meta.fileName, '2026-06-07_Jane_Smith.docx');
    expect(meta.status, EntrySupportNoteStatus.submitted);
    expect(meta.parentFolderId, 'year-folder');
    expect(meta.openLink, 'https://drive.example/paye-note');
    expect(meta.googleAccountEmail, 'paye@example.com');
  });

  test(
    'findPayeNotesInDrive returns matching Google Doc and legacy docx',
    () async {
      final api = _FakeGoogleDriveApi(
        childrenByParent: {
          'paye-notes': [
            const GoogleDriveFile(
              id: 'person-folder',
              name: 'Jane Smith',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'person-folder': [
            const GoogleDriveFile(
              id: 'year-folder',
              name: '2026',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'year-folder': [
            const GoogleDriveFile(
              id: 'paye-doc',
              name: '2026-06-07_Jane_Smith',
              mimeType: _googleDocsMimeType,
            ),
            const GoogleDriveFile(
              id: 'paye-docx',
              name: '2026-06-07_Jane_Smith.docx',
              mimeType: _docxMimeType,
            ),
            const GoogleDriveFile(
              id: 'other-doc',
              name: '2026-06-08_Jane_Smith',
              mimeType: _googleDocsMimeType,
            ),
          ],
        },
      );
      final service = GoogleDriveService(api: api);

      final matches = await service.findPayeNotesInDrive(
        accessToken: 'token',
        notesFolderId: 'paye-notes',
        entry: WorkEntry(
          id: 'paye-1',
          client: 'Jane Smith',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 7),
          startTime: const TimeOfDay(hour: 10, minute: 30),
          minutes: 30,
          notes: const [],
        ),
        googleAccountEmail: 'paye@example.com',
      );

      expect(matches.map((meta) => meta.fileId), ['paye-doc', 'paye-docx']);
      expect(matches.map((meta) => meta.mimeType), [
        _googleDocsMimeType,
        _docxMimeType,
      ]);
      expect(matches.map((meta) => meta.status).toSet(), {
        EntrySupportNoteStatus.submitted,
      });
    },
  );

  test(
    'findSupportNoteInDrive returns existing submitted Google Doc',
    () async {
      final api = _FakeGoogleDriveApi(
        childrenByParent: {
          'client-notes': [
            const GoogleDriveFile(
              id: 'client-folder',
              name: 'AB',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'client-folder': [
            const GoogleDriveFile(
              id: 'period-folder',
              name: 'Invoice 10 - 2026-06-01 to 2026-06-14',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'period-folder': [
            const GoogleDriveFile(
              id: 'type-folder',
              name: 'Professional Contacts',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'type-folder': [
            const GoogleDriveFile(
              id: 'drive-note',
              name: '2026-06-09_AB_submitted',
              mimeType: _googleDocsMimeType,
              webViewLink: 'https://drive.example/submitted-note',
            ),
          ],
        },
      );
      final service = GoogleDriveService(api: api);

      final meta = await service.findSupportNoteInDrive(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.professionalContact,
          date: DateTime(2026, 6, 9),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 30,
          notes: const [],
        ),
      );

      expect(meta, isNotNull);
      expect(meta!.fileId, 'drive-note');
      expect(meta.status, EntrySupportNoteStatus.submitted);
      expect(meta.mimeType, _googleDocsMimeType);
      expect(meta.openLink, 'https://drive.example/submitted-note');
    },
  );

  test('saveSupportNote files text notes under Texts', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    await service.saveSupportNote(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-1',
        client: 'AB',
        type: EntryType.textNote,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 20,
        notes: const ['Text update'],
      ),
      initials: 'AB',
      status: EntrySupportNoteStatus.inProgress,
      noteText: 'Main topic(s)\nText update',
    );

    final noteUpload = api.uploads.singleWhere(
      (upload) => upload.name.endsWith('_AB_in-progress'),
    );

    expect(noteUpload.parentId, contains('/Texts'));
  });

  test('saveSupportNote files phone calls under Phone Calls', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    await service.saveSupportNote(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-1',
        client: 'AB',
        type: EntryType.phoneCall,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 30,
        notes: const ['Phone call'],
      ),
      initials: 'AB',
      status: EntrySupportNoteStatus.inProgress,
      noteText: 'Main topic(s)\nPhone call',
    );

    final noteUpload = api.uploads.singleWhere(
      (upload) => upload.name.endsWith('_AB_in-progress'),
    );

    expect(noteUpload.parentId, contains('/Phone Calls'));
  });

  test('saveSupportNote files finished phone calls under Finished', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    final meta = await service.saveSupportNote(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-1',
        client: 'AB',
        type: EntryType.phoneCall,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 30,
        notes: const ['Phone call'],
      ),
      initials: 'AB',
      status: EntrySupportNoteStatus.finished,
      noteText: 'Main topic(s)\nPhone call finished',
    );

    final noteUpload = api.uploads.singleWhere(
      (upload) => upload.name.endsWith('_AB_finished'),
    );

    expect(noteUpload.parentId, contains('/Phone Calls/Finished'));
    expect(meta.parentFolderId, contains('/Phone Calls/Finished'));
  });

  test('findSupportNoteInDrive finds completed notes under Finished', () async {
    final api = _FakeGoogleDriveApi(
      childrenByParent: {
        'client-notes': [
          const GoogleDriveFile(
            id: 'client-folder',
            name: 'AB',
            mimeType: 'application/vnd.google-apps.folder',
          ),
        ],
        'client-folder': [
          const GoogleDriveFile(
            id: 'period-folder',
            name: 'Invoice 10 - 2026-05-31 to 2026-06-13',
            mimeType: 'application/vnd.google-apps.folder',
          ),
        ],
        'period-folder': [
          const GoogleDriveFile(
            id: 'type-folder',
            name: 'Phone Calls',
            mimeType: 'application/vnd.google-apps.folder',
          ),
        ],
        'type-folder': [
          const GoogleDriveFile(
            id: 'finished-folder',
            name: 'Finished',
            mimeType: 'application/vnd.google-apps.folder',
          ),
          const GoogleDriveFile(
            id: 'draft-note',
            name: '2026-06-02_AB_in-progress',
            mimeType: _googleDocsMimeType,
          ),
        ],
        'finished-folder': [
          const GoogleDriveFile(
            id: 'finished-note',
            name: '2026-06-02_AB_finished',
            mimeType: _googleDocsMimeType,
            webViewLink: 'https://docs.example/finished-note',
          ),
        ],
      },
    );
    final service = GoogleDriveService(api: api);

    final meta = await service.findSupportNoteInDrive(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-1',
        client: 'AB',
        type: EntryType.phoneCall,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 30,
        notes: const ['Phone call'],
      ),
    );

    expect(meta?.fileId, 'finished-note');
    expect(meta?.status, EntrySupportNoteStatus.finished);
    expect(meta?.parentFolderId, 'finished-folder');
    expect(meta?.openLink, 'https://docs.example/finished-note');
  });

  test(
    'saveSupportNote replaces existing Google Docs notes through Drive',
    () async {
      final api = _FakeGoogleDriveApi(children: const []);
      final service = GoogleDriveService(api: api);

      final meta = await service.saveSupportNote(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ),
        initials: 'AB',
        status: EntrySupportNoteStatus.inProgress,
        noteText:
            'Main topic(s)\nTest note\n\nSecond paragraph\n\n'
            'Outcome(s)\nSaved to Drive',
        existingMeta: const EntryDriveSupportNoteMeta(
          entryId: 'entry-1',
          initials: 'AB',
          status: EntrySupportNoteStatus.incomplete,
          fileId: 'legacy-google-doc',
          fileName: '2026-06-02_AB_incomplete',
          noteText: 'Old note',
          mimeType: EntryDriveSupportNoteMeta.googleDocsMimeType,
        ),
      );

      final replacement = api.uploads.single;
      final replacementText = _docxText(replacement.bytes);
      final paragraphs = _docxParagraphTexts(replacement.bytes);
      final mainLine = paragraphs.indexOf('Test note');
      final secondLine = paragraphs.indexOf('Second paragraph');

      expect(api.uploadedNames, contains('2026-06-02_AB_in-progress'));
      expect(api.updates, isEmpty);
      expect(api.deletedFileIds, contains('legacy-google-doc'));
      expect(replacement.name, '2026-06-02_AB_in-progress');
      expect(replacement.mimeType, _googleDocsMimeType);
      expect(replacement.contentMimeType, _docxMimeType);
      expect(replacementText, contains('Test note'));
      expect(mainLine, isNonNegative);
      expect(secondLine, greaterThan(mainLine));
      expect(paragraphs.sublist(mainLine + 1, secondLine), contains(''));
      expect(meta.fileName, '2026-06-02_AB_in-progress');
      expect(meta.mimeType, _googleDocsMimeType);
      expect(meta.noteText, contains('Test note\n\nSecond paragraph'));
      expect(meta.noteText, contains('Second paragraph\n\nOutcome(s)'));
      expect(meta.noteText, contains('Next action(s)\n\nOverall impression'));
      expect(meta.contentFormat, EntryDriveSupportNoteMeta.stableContentFormat);
    },
  );

  test(
    'saveSupportNote reuses date-matched Google Doc after status rename',
    () async {
      final api = _FakeGoogleDriveApi(
        childrenByParent: {
          'client-notes': [
            const GoogleDriveFile(
              id: 'client-folder',
              name: 'Jane Smith',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'client-folder': [
            const GoogleDriveFile(
              id: 'period-folder',
              name: 'Invoice 10 - 2026-06-01 to 2026-06-14',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'period-folder': [
            const GoogleDriveFile(
              id: 'type-folder',
              name: 'Home Visits',
              mimeType: 'application/vnd.google-apps.folder',
            ),
          ],
          'type-folder': [
            const GoogleDriveFile(
              id: 'existing-google-doc',
              name: '2026-06-02_Jane_Smith_incomplete',
              mimeType: _googleDocsMimeType,
            ),
          ],
          'client-folder/Invoice 10 - 2026-05-31 to 2026-06-13/Home Visits': [
            const GoogleDriveFile(
              id: 'existing-google-doc',
              name: '2026-06-02_Jane_Smith_incomplete',
              mimeType: _googleDocsMimeType,
            ),
          ],
        },
      );
      final service = GoogleDriveService(api: api);

      final meta = await service.saveSupportNote(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'Jane Smith',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ),
        initials: 'JS',
        status: EntrySupportNoteStatus.submitted,
        noteText: 'Main topic(s)\nUpdated in app',
      );

      final replacement = api.uploads.single;
      expect(api.updates, isEmpty);
      expect(api.deletedFileIds, contains('existing-google-doc'));
      expect(replacement.name, '2026-06-02_Jane_Smith_submitted');
      expect(_docxText(replacement.bytes), contains('Updated in app'));
      expect(meta.fileId, 'new-doc');
      expect(meta.fileName, '2026-06-02_Jane_Smith_submitted');
      expect(meta.status, EntrySupportNoteStatus.submitted);
    },
  );

  test('saveSupportNote converts an existing docx into a Google Doc', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    final meta = await service.saveSupportNote(
      accessToken: 'token',
      clientNotesFolderId: 'client-notes',
      entry: WorkEntry(
        id: 'entry-1',
        client: 'AB',
        type: EntryType.phoneCall,
        date: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 30,
        notes: const ['Phone call'],
      ),
      initials: 'AB',
      status: EntrySupportNoteStatus.inProgress,
      noteText: 'Main topic(s)\nPhone call',
      existingMeta: const EntryDriveSupportNoteMeta(
        entryId: 'entry-1',
        initials: 'AB',
        status: EntrySupportNoteStatus.inProgress,
        fileId: 'existing-docx',
        fileName: '2026-06-02_AB_in-progress.docx',
        noteText: 'Old note',
        mimeType: _docxMimeType,
        parentFolderId: 'client-notes/AB/Invoice 10 - 2026-06-01 to 2026-06-14',
      ),
    );

    expect(api.movedFiles, isEmpty);
    expect(api.updatedFileIds, isNot(contains('existing-docx')));
    expect(api.uploadedNames, contains('2026-06-02_AB_in-progress'));
    expect(meta.mimeType, _googleDocsMimeType);
    expect(meta.parentFolderId, contains('/Phone Calls'));
  });

  test(
    'saveSupportNote creates a new file when Google account changes',
    () async {
      final api = _FakeGoogleDriveApi(children: const []);
      final service = GoogleDriveService(api: api);

      final meta = await service.saveSupportNote(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        entry: WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ),
        initials: 'AB',
        status: EntrySupportNoteStatus.inProgress,
        noteText: 'Main topic(s)\nNew account note',
        googleAccountEmail: 'new-work@example.com',
        existingMeta: const EntryDriveSupportNoteMeta(
          entryId: 'entry-1',
          initials: 'AB',
          status: EntrySupportNoteStatus.inProgress,
          fileId: 'old-account-docx',
          fileName: '2026-06-02_AB_in-progress.docx',
          noteText: 'Old account note',
          mimeType: _docxMimeType,
          parentFolderId:
              'client-notes/AB/Invoice 10 - 2026-06-01 to 2026-06-14',
          googleAccountEmail: 'old-work@example.com',
        ),
      );

      expect(api.updatedFileIds, isNot(contains('old-account-docx')));
      expect(api.uploadedNames, contains('2026-06-02_AB_in-progress'));
      expect(meta.fileId, 'new-doc');
      expect(meta.googleAccountEmail, 'new-work@example.com');
    },
  );

  test(
    'syncPersonalLogEntries files gym notes under split and exercise',
    () async {
      final api = _FakeGoogleDriveApi(children: const []);
      final service = GoogleDriveService(api: api);

      await service.syncPersonalLogEntries(
        accessToken: 'token',
        personalNotesFolderId: 'personal-notes',
        entries: [
          PersonalLogEntry(
            id: 'personal-1',
            category: PersonalLogCategory.gym,
            date: DateTime(2026, 6, 4),
            title: 'Legs: Squat',
            metric: '80 kg | 3 x 5 reps',
            notes: 'Good depth and stable knees.',
          ),
        ],
      );

      final noteUpload = api.uploads.singleWhere(
        (upload) => upload.name.endsWith('_gym_Legs-_Squat.docx'),
      );
      final documentText = _docxText(noteUpload.bytes);

      expect(noteUpload.parentId, 'personal-notes/Gym/Legs/Squat/2026');
      expect(noteUpload.mimeType, _docxMimeType);
      expect(documentText, contains('Personal Progress Log'));
      expect(documentText, contains('Sets, reps, and load'));
      expect(documentText, contains('Performance notes'));
      expect(documentText, contains('Next target'));
      expect(documentText, contains('80 kg | 3 x 5 reps'));
      expect(documentText, contains('Good depth and stable knees.'));
      expect(documentText, isNot(contains('Name of client')));
      expect(documentText, isNot(contains('Safety concerns')));
    },
  );

  test(
    'syncPersonalLogEntries groups mood voice notes into one health Google Doc',
    () async {
      final api = _FakeGoogleDriveApi(children: const []);
      final service = GoogleDriveService(api: api);

      await service.syncPersonalLogEntries(
        accessToken: 'token',
        personalNotesFolderId: 'personal-notes',
        entries: [
          PersonalLogEntry(
            id: 'voice-1',
            category: PersonalLogCategory.health,
            date: DateTime(2026, 6, 2, 9, 5),
            title: 'Mood voice note',
            metric: moodVoiceNoteMetric,
            notes: 'Morning felt steady after breakfast.',
          ),
          PersonalLogEntry(
            id: 'voice-2',
            category: PersonalLogCategory.health,
            date: DateTime(2026, 7, 1, 18, 30),
            title: 'Mood voice note',
            metric: moodVoiceNoteMetric,
            notes: 'Evening anxiety settled after a walk.',
          ),
          PersonalLogEntry(
            id: 'health-1',
            category: PersonalLogCategory.health,
            date: DateTime(2026, 6, 3),
            title: 'Sleep',
            metric: '7 hours',
            notes: 'Woke once.',
          ),
        ],
      );

      final voiceUpload = api.uploads.singleWhere(
        (upload) => upload.name == 'Mood Voice Notes',
      );
      final documentText = _docxText(voiceUpload.bytes);

      expect(voiceUpload.parentId, 'personal-notes/Health');
      expect(voiceUpload.mimeType, _googleDocsMimeType);
      expect(voiceUpload.contentMimeType, _docxMimeType);
      expect(api.uploadedNames, contains('Mood Voice Notes'));
      expect(
        api.uploadedNames,
        isNot(contains('2026-06-02_health_Mood_voice_note.docx')),
      );
      expect(documentText, contains('Mood Voice Notes'));
      expect(documentText, contains('One living Google Doc'));
      expect(documentText, contains('July 2026'));
      expect(documentText, contains('01/07/2026 6:30 PM'));
      expect(documentText, contains('Evening anxiety settled after a walk.'));
      expect(documentText, contains('June 2026'));
      expect(documentText, contains('02/06/2026 9:05 AM'));
      expect(documentText, contains('Morning felt steady after breakfast.'));
      expect(documentText, isNot(contains('Sleep')));
    },
  );

  test('savePayeNote imports long PAYE notes as a Google Doc', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    await service.savePayeNote(
      accessToken: 'token',
      notesFolderId: 'paye-notes',
      entry: WorkEntry(
        id: 'paye-1',
        client: 'Jane Smith',
        type: EntryType.homeVisit,
        date: DateTime(2026, 6, 7),
        startTime: const TimeOfDay(hour: 10, minute: 30),
        minutes: 30,
        notes: const [
          'Attendance: Client, Support worker, Social worker',
          'Roster question answered',
        ],
        odometerStart: 10,
        odometerEnd: 14.5,
        supportNoteBreakdown: [
          'What happened',
          'Roster question answered',
          List.filled(220, 'Long session detail.').join(' '),
          '',
          'Work/task completed',
          'Roster checked',
          '',
          'Support given',
          'Explained the roster change and answered questions',
          '',
          'Issue/problem',
          'Unclear shift note',
          '',
          'Outcome',
          'Shift confirmed',
          '',
          'Next step',
          'Send policy link',
          '',
          'Anything to follow up',
          'Check client received link',
          '',
          'Referrals',
          'None',
        ].join('\n'),
      ),
    );

    final upload = api.uploads.singleWhere(
      (item) => item.name == '2026-06-07_Jane_Smith',
    );
    final documentText = _docxText(upload.bytes);

    expect(upload.parentId, 'paye-notes/Jane Smith/2026');
    expect(upload.mimeType, _googleDocsMimeType);
    expect(upload.contentMimeType, _docxMimeType);
    expect(documentText, startsWith('Attendance'));
    expect(documentText, contains('Client'));
    expect(documentText, contains('Support worker'));
    expect(documentText, contains('Social worker'));
    expect(documentText, isNot(contains('PAYE Support Note')));
    expect(documentText, isNot(contains('Date:')));
    expect(documentText, isNot(contains('Jane Smith')));
    expect(documentText, contains('Roster question answered'));
    expect(documentText, contains('Long session detail.'));
    expect(documentText, contains('Work/task completed'));
    expect(documentText, contains('Roster checked'));
    expect(documentText, contains('Support given'));
    expect(documentText, contains('Issue/problem'));
    expect(documentText, contains('Shift confirmed'));
    expect(documentText, contains('Next step'));
    expect(documentText, contains('Send policy link'));
    expect(documentText, contains('Anything to follow up'));
    expect(documentText, contains('Check client received link'));
    expect(documentText, contains('Referrals'));
    expect(documentText, isNot(contains('Kilometres')));
    expect(documentText, isNot(contains('Invoice')));
  });

  test('deleteFile sends permanent file removal through Drive API', () async {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    await service.deleteFile(accessToken: 'token', fileId: 'temporary-doc');

    expect(api.deletedFileIds, ['temporary-doc']);
  });

  test('exportGoogleDocText reads editable Google Doc text', () async {
    final api = _FakeGoogleDriveApi(exportedText: 'Edited Google Doc note');
    final service = GoogleDriveService(api: api);

    final text = await service.exportGoogleDocText(
      accessToken: 'token',
      meta: const EntryDriveSupportNoteMeta(
        entryId: 'entry-1',
        initials: 'AB',
        status: EntrySupportNoteStatus.finished,
        fileId: 'google-doc-id',
        fileName: 'PAYE Google Doc',
        noteText: '',
        mimeType: EntryDriveSupportNoteMeta.googleDocsMimeType,
      ),
    );

    expect(text, 'Edited Google Doc note');
    expect(api.exportedFileIds, ['google-doc-id']);
  });
}

const _docxMimeType =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const _googleDocsMimeType = 'application/vnd.google-apps.document';

class _FakeGoogleDriveApi extends GoogleDriveApiPlatform {
  _FakeGoogleDriveApi({
    this.children = const [],
    this.childrenByParent = const {},
    this.exportedText = '',
  });

  final List<GoogleDriveFile> children;
  final Map<String, List<GoogleDriveFile>> childrenByParent;
  final String exportedText;
  final uploads = <_Upload>[];
  final updates = <_Update>[];
  final movedFiles = <_Move>[];
  final uploadedNames = <String>[];
  final updatedFileIds = <String>[];
  final deletedFileIds = <String>[];
  final exportedFileIds = <String>[];

  @override
  Future<GoogleDriveFile> createFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) async {
    return GoogleDriveFile(
      id: parentId == null ? name : '$parentId/$name',
      name: name,
      mimeType: 'application/vnd.google-apps.folder',
    );
  }

  @override
  Future<List<GoogleDriveFile>> listChildren({
    required String accessToken,
    required String parentId,
  }) async {
    return childrenByParent[parentId] ?? children;
  }

  @override
  Future<GoogleDriveFile> uploadFile({
    required String accessToken,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required String parentId,
    String? contentMimeType,
  }) async {
    uploadedNames.add(name);
    uploads.add(
      _Upload(
        parentId: parentId,
        name: name,
        mimeType: mimeType,
        contentMimeType: contentMimeType,
        bytes: bytes,
      ),
    );
    return GoogleDriveFile(id: 'new-doc', name: name, mimeType: mimeType);
  }

  @override
  Future<GoogleDriveFile> updateFile({
    required String accessToken,
    required String fileId,
    required String name,
    required String mimeType,
    required List<int> bytes,
    String? contentMimeType,
  }) async {
    updatedFileIds.add(fileId);
    updates.add(
      _Update(
        fileId: fileId,
        name: name,
        mimeType: mimeType,
        contentMimeType: contentMimeType,
        bytes: bytes,
      ),
    );
    return GoogleDriveFile(id: fileId, name: name, mimeType: mimeType);
  }

  @override
  Future<GoogleDriveFile> moveFile({
    required String accessToken,
    required String fileId,
    required String fromParentId,
    required String toParentId,
  }) async {
    movedFiles.add(
      _Move(fileId: fileId, fromParentId: fromParentId, toParentId: toParentId),
    );
    return const GoogleDriveFile(
      id: 'existing-docx',
      name: '2026-06-02_AB_in-progress.docx',
      mimeType: _docxMimeType,
    );
  }

  @override
  Future<void> deleteFile({
    required String accessToken,
    required String fileId,
  }) async {
    deletedFileIds.add(fileId);
  }

  @override
  Future<String> exportGoogleDocText({
    required String accessToken,
    required String fileId,
  }) async {
    exportedFileIds.add(fileId);
    return exportedText;
  }
}

class _Upload {
  const _Upload({
    required this.parentId,
    required this.name,
    required this.mimeType,
    required this.contentMimeType,
    required this.bytes,
  });

  final String parentId;
  final String name;
  final String mimeType;
  final String? contentMimeType;
  final List<int> bytes;
}

class _Update {
  const _Update({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.contentMimeType,
    required this.bytes,
  });

  final String fileId;
  final String name;
  final String mimeType;
  final String? contentMimeType;
  final List<int> bytes;
}

class _Move {
  const _Move({
    required this.fileId,
    required this.fromParentId,
    required this.toParentId,
  });

  final String fileId;
  final String fromParentId;
  final String toParentId;
}

String _docxText(List<int> bytes) {
  final xml = _docxXml(bytes);

  return RegExp(
    r'<w:t[^>]*>(.*?)<\/w:t>',
  ).allMatches(xml).map((match) => _unxml(match.group(1)!)).join(' ');
}

List<String> _docxParagraphTexts(List<int> bytes) {
  final xml = _docxXml(bytes);

  return RegExp(r'<w:p(?:\s|>)[\s\S]*?<\/w:p>').allMatches(xml).map((match) {
    final paragraph = match.group(0)!;
    return RegExp(
      r'<w:t[^>]*>(.*?)<\/w:t>',
    ).allMatches(paragraph).map((text) => _unxml(text.group(1)!)).join();
  }).toList();
}

String _docxXml(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final document = archive.files.firstWhere(
    (file) => file.name == 'word/document.xml',
  );

  return utf8.decode(document.content as List<int>);
}

bool _paragraphHasBoldText(String xml, String text) {
  final encodedText = text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  return RegExp(
    '<w:p[\\s\\S]*?<w:b[\\s\\S]*?<w:t[^>]*>$encodedText</w:t>[\\s\\S]*?</w:p>',
  ).hasMatch(xml);
}

String _unxml(String value) {
  return value
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&amp;', '&');
}
