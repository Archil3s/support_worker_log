import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/google_drive_file.dart';
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
      expect(noteUpload.mimeType, _docxMimeType);
      expect(noteUpload.contentMimeType, isNull);
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
}

const _docxMimeType =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

class _FakeGoogleDriveApi extends GoogleDriveApiPlatform {
  _FakeGoogleDriveApi({required this.children});

  final List<GoogleDriveFile> children;
  final uploads = <_Upload>[];
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
