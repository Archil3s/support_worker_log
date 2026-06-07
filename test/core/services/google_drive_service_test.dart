import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    'saveSupportNote uploads template docx content as a Drive docx file',
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
            'Main topic(s)\nTest note\n\n'
            'Outcome(s)\nSaved to Drive\n\n'
            'Next action(s)\nFollow up tomorrow\n\n'
            'Overall impression\nSettled\n\n'
            'Local referral tracking\n'
            'No referrals discussed or made this visit.\n\n'
            'Safety concerns for sexual harm survivors and mental health\n'
            'No safety concerns noted.',
      );

      final noteUpload = api.uploads.singleWhere(
        (upload) => upload.name.endsWith('_AB_in-progress.docx'),
      );
      final documentXml = _docxXml(noteUpload.bytes);
      final documentText = _docxText(noteUpload.bytes);

      expect(meta.fileName, endsWith('.docx'));
      expect(meta.mimeType, _docxMimeType);
      expect(meta.openLink, 'https://drive.google.com/file/d/new-doc/view');
      expect(
        meta.folderOpenLink,
        startsWith('https://drive.google.com/drive/folders/'),
      );
      expect(meta.folderOpenLink, contains('client-notes%2FAB%2FInvoice%2010'));
      expect(meta.folderOpenLink, contains('Home%20Visits'));
      expect(noteUpload.mimeType, _docxMimeType);
      expect(noteUpload.contentMimeType, isNull);
      expect(noteUpload.parentId, contains('/Home Visits'));
      expect(documentText, contains('Name of client: AB'));
      expect(documentText, contains('Main topic(s)  (max. 200 words)'));
      expect(documentText, contains('Test note'));
      expect(documentText, contains('Outcome(s)  (Max. 100 words)'));
      expect(documentText, contains('Saved to Drive'));
      expect(documentText, contains('Next actions  Max. 150 words)'));
      expect(documentText, contains('Follow up tomorrow'));
      expect(documentText, contains('Settled'));
      expect(
        documentText.indexOf('Local referral tracking'),
        greaterThan(documentText.indexOf('Follow up tomorrow')),
      );
      expect(
        documentText.indexOf(
          'Safety concerns for sexual harm survivors and mental health',
        ),
        greaterThan(documentText.indexOf('No referrals discussed')),
      );
      expect(
        _paragraphHasBoldText(documentXml, 'Local referral tracking'),
        true,
      );
      expect(
        _paragraphHasBoldText(
          documentXml,
          'Safety concerns for sexual harm survivors and mental health',
        ),
        true,
      );
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
      (upload) => upload.name.endsWith('_AB_in-progress.docx'),
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
      (upload) => upload.name.endsWith('_AB_in-progress.docx'),
    );

    expect(noteUpload.parentId, contains('/Phone Calls'));
  });

  test(
    'saveSupportNote replaces legacy converted Docs metadata with docx',
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
        noteText: 'Main topic(s)\nTest note',
        existingMeta: const EntryDriveSupportNoteMeta(
          entryId: 'entry-1',
          initials: 'AB',
          status: EntrySupportNoteStatus.inProgress,
          fileId: 'legacy-google-doc',
          fileName: '2026-06-02_AB_in-progress.docx',
          noteText: 'Old note',
          mimeType: EntryDriveSupportNoteMeta.googleDocsMimeType,
        ),
      );

      expect(api.updatedFileIds, isNot(contains('legacy-google-doc')));
      expect(api.uploadedNames, contains('2026-06-02_AB_in-progress.docx'));
      expect(meta.mimeType, _docxMimeType);
      expect(meta.contentFormat, EntryDriveSupportNoteMeta.stableContentFormat);
    },
  );

  test('saveSupportNote moves an existing docx into the type folder', () async {
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

    expect(api.movedFiles.single.fileId, 'existing-docx');
    expect(api.movedFiles.single.toParentId, contains('/Phone Calls'));
    expect(api.updatedFileIds, contains('existing-docx'));
    expect(
      api.uploadedNames,
      isNot(contains('2026-06-02_AB_in-progress.docx')),
    );
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
      expect(api.uploadedNames, contains('2026-06-02_AB_in-progress.docx'));
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

  test('syncPersonalLivingSheet uploads a live Excel dashboard', () {
    final api = _FakeGoogleDriveApi(children: const []);
    final service = GoogleDriveService(api: api);

    return service
        .syncPersonalLivingSheet(
          accessToken: 'token',
          parentFolderId: 'personal-root',
          entries: [
            PersonalLogEntry(
              id: 'personal-1',
              category: PersonalLogCategory.gym,
              date: DateTime(2026, 6, 4),
              title: 'Push: Bench Press',
              metric: '80 kg | 3 x 5 reps',
              notes: 'Solid.',
            ),
          ],
        )
        .then((_) {
          final upload = api.uploads.singleWhere(
            (item) => item.name == 'Personal Log - Live Dashboard.xlsx',
          );

          expect(upload.parentId, 'personal-root');
          expect(upload.mimeType, _xlsxMimeType);
          expect(upload.contentMimeType, _xlsxMimeType);
          expect(
            Excel.decodeBytes(upload.bytes).sheets.keys,
            containsAll([
              'Dashboard',
              'Gym Summary',
              'Workout Trend',
              'Body Weight',
              'Personal Logs',
            ]),
          );
        });
  });

  test(
    'savePayeNote stores blank docx under person and year folders',
    () async {
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
          notes: const ['Roster question answered'],
          odometerStart: 10,
          odometerEnd: 14.5,
          supportNoteBreakdown:
              'Main topic(s)\nRoster question answered\n\n'
              'Outcome(s)\nShift confirmed\n\n'
              'Next action(s)\nSend policy link\n\n'
              'Overall impression\nSettled\n\n'
              'Local referral tracking\nNone\n\n'
              'Safety concerns\nNone noted',
        ),
      );

      final upload = api.uploads.singleWhere(
        (item) => item.name == '2026-06-07_Jane_Smith.docx',
      );
      final documentText = _docxText(upload.bytes);

      expect(upload.parentId, 'paye-notes/Jane Smith/2026');
      expect(upload.mimeType, _docxMimeType);
      expect(documentText, contains('PAYE Support Note'));
      expect(documentText, contains('Jane Smith'));
      expect(documentText, contains('Roster question answered'));
      expect(documentText, contains('Shift confirmed'));
      expect(documentText, contains('Send policy link'));
      expect(documentText, isNot(contains('Kilometres')));
      expect(documentText, isNot(contains('Invoice')));
    },
  );
}

const _docxMimeType =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class _FakeGoogleDriveApi extends GoogleDriveApiPlatform {
  _FakeGoogleDriveApi({required this.children});

  final List<GoogleDriveFile> children;
  final uploads = <_Upload>[];
  final movedFiles = <_Move>[];
  final uploadedNames = <String>[];
  final updatedFileIds = <String>[];

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
    return children;
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
