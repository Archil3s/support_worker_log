import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/google_drive_file.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/drive_invoice_cycle_sync_service.dart';
import 'package:support_worker_log/core/services/google_drive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'sync writes text notes to one living Drive document per client',
    () async {
      final driveService = _FakeGoogleDriveService();
      final syncService = DriveInvoiceCycleSyncService(
        driveService: driveService,
      );

      await syncService.syncInvoiceCycles(
        accessToken: 'token',
        clientNotesFolderId: 'client-notes',
        invoicesFolderId: 'invoices',
        entries: [
          WorkEntry(
            id: 'entry-1',
            client: 'AB',
            type: EntryType.textNote,
            date: DateTime(2026, 5, 31),
            startTime: const TimeOfDay(hour: 15, minute: 0),
            minutes: 20,
            notes: const ['Text update'],
            importantText: true,
            textContactDirection: TextContactDirection.received,
            textReplyNeeded: true,
          ),
          WorkEntry(
            id: 'entry-2',
            client: 'CD',
            type: EntryType.textNote,
            date: DateTime(2026, 6, 1),
            startTime: const TimeOfDay(hour: 8, minute: 15),
            minutes: 10,
            notes: const ['Check-in'],
            textContactDirection: TextContactDirection.sent,
          ),
        ],
        settings: const AppSettings(),
      );

      final livingLogUploads = driveService.uploads.where(
        (upload) => upload.name == 'Living_Text_Notes_Log.docx',
      );

      expect(livingLogUploads, hasLength(2));

      final abLogUpload = livingLogUploads.singleWhere(
        (upload) => upload.parentId == 'client-notes/AB',
      );
      final cdLogUpload = livingLogUploads.singleWhere(
        (upload) => upload.parentId == 'client-notes/CD',
      );
      final abDocumentText = _docxText(abLogUpload.bytes);
      final cdDocumentText = _docxText(cdLogUpload.bytes);

      expect(abDocumentText, contains('Name of client: AB'));
      expect(abDocumentText, contains('AB Living Text Notes Log'));
      expect(abDocumentText, contains('31/05/2026 15:00 - AB'));
      expect(abDocumentText, contains('Date: 31/05/2026'));
      expect(abDocumentText, contains('Time: 15:00'));
      expect(abDocumentText, contains('Direction: Text received'));
      expect(abDocumentText, contains('Important: Important'));
      expect(abDocumentText, contains('Reply needed: Yes'));
      expect(abDocumentText, isNot(contains('01/06/2026 08:15 - CD')));
      expect(cdDocumentText, contains('Name of client: CD'));
      expect(cdDocumentText, contains('CD Living Text Notes Log'));
      expect(cdDocumentText, contains('01/06/2026 08:15 - CD'));
      expect(cdDocumentText, contains('Direction: Text sent'));
      expect(cdDocumentText, contains('Important: Not important'));
      expect(cdDocumentText, contains('Reply needed: No'));
      expect(
        driveService.uploads.where(
          (upload) => upload.name.endsWith('_Communication_Log.docx'),
        ),
        isEmpty,
      );
    },
  );
}

String _docxText(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final document = archive.files.firstWhere(
    (file) => file.name == 'word/document.xml',
  );
  final xml = utf8.decode(document.content as List<int>);

  return RegExp(
    r'<w:t[^>]*>(.*?)<\/w:t>',
  ).allMatches(xml).map((match) => _unxml(match.group(1)!)).join(' ');
}

String _unxml(String value) {
  return value
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&amp;', '&');
}

class _FakeGoogleDriveService extends GoogleDriveService {
  final uploads = <_DriveUpload>[];

  @override
  Future<GoogleDriveFile> findOrCreateFolder({
    required String accessToken,
    required String parentId,
    required String name,
  }) async {
    return GoogleDriveFile(
      id: '$parentId/$name',
      name: name,
      mimeType: 'application/vnd.google-apps.folder',
    );
  }

  @override
  Future<GoogleDriveFile> uploadOrUpdateFile({
    required String accessToken,
    required String parentId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    uploads.add(
      _DriveUpload(
        parentId: parentId,
        name: name,
        mimeType: mimeType,
        bytes: bytes,
      ),
    );

    return GoogleDriveFile(id: name, name: name, mimeType: mimeType);
  }
}

class _DriveUpload {
  const _DriveUpload({
    required this.parentId,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String parentId;
  final String name;
  final String mimeType;
  final List<int> bytes;
}
