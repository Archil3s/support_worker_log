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
import 'package:support_worker_log/core/utils/pay_period_utils.dart';

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
        rootFolderId: 'root',
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

      expect(abDocumentText, contains('Name of client. AB'));
      expect(abDocumentText, contains('Template for reporting'));
      expect(abDocumentText, contains('Attendance'));
      expect(abDocumentText, contains('What happened'));
      expect(abDocumentText, contains('Work/task completed'));
      expect(abDocumentText, contains('Support given'));
      expect(abDocumentText, contains('Issue/problem'));
      expect(abDocumentText, contains('Outcome'));
      expect(abDocumentText, contains('Next step'));
      expect(abDocumentText, contains('Anything to follow up'));
      expect(abDocumentText, contains('Referrals'));
      expect(abDocumentText, contains('Main topic(s)'));
      expect(abDocumentText, contains('Outcome(s)'));
      expect(abDocumentText, contains('Next actions'));
      expect(abDocumentText, contains('Overall impression'));
      expect(abDocumentText, contains('AB Living Text Notes Log'));
      expect(abDocumentText, contains('31/05/2026 15:00 - AB'));
      expect(abDocumentText, contains('Date: 31/05/2026'));
      expect(abDocumentText, contains('Time: 15:00'));
      expect(abDocumentText, contains('Direction: Text received'));
      expect(abDocumentText, contains('Important: Important'));
      expect(abDocumentText, contains('Reply needed: Yes'));
      expect(abDocumentText, isNot(contains('01/06/2026 08:15 - CD')));
      expect(cdDocumentText, contains('Name of client. CD'));
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
  test('sync uses tab invoice number for anchored invoice periods', () async {
    final driveService = _FakeGoogleDriveService();
    final syncService = DriveInvoiceCycleSyncService(
      driveService: driveService,
    );

    await syncService.syncInvoiceCycles(
      accessToken: 'token',
      rootFolderId: 'root',
      clientNotesFolderId: 'client-notes',
      invoicesFolderId: 'invoices',
      entries: [
        WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2025, 11, 29),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const ['Anchor period'],
          odometerStart: 100,
          odometerEnd: 101,
        ),
        WorkEntry(
          id: 'entry-2',
          client: 'CD',
          type: EntryType.homeVisit,
          date: DateTime(2026, 5, 30),
          startTime: const TimeOfDay(hour: 10, minute: 0),
          minutes: 60,
          notes: const ['Invoice 18 period'],
          odometerStart: 200,
          odometerEnd: 201,
        ),
      ],
      settings: AppSettings(payPeriodAnchorDate: DateTime(2025, 11, 29)),
    );

    expect(
      driveService.uploads.map((upload) => upload.name),
      contains('Invoice_18_2026-05-30_2026-06-12.pdf'),
    );
    expect(
      driveService.uploads
          .where((upload) => upload.name.endsWith('.pdf'))
          .map((upload) => upload.parentId),
      contains('invoices/Invoice 18 - 2026-05-30 to 2026-06-12'),
    );
  });
  test('createInvoicePeriodTotalFolder uploads full period file set', () async {
    final driveService = _FakeGoogleDriveService();
    final syncService = DriveInvoiceCycleSyncService(
      driveService: driveService,
    );
    final range = PayPeriodRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 14),
    );

    final folder = await syncService.createInvoicePeriodTotalFolder(
      accessToken: 'token',
      invoicesFolderId: 'invoices',
      invoiceNumber: 24,
      range: range,
      entries: [
        WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 2),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const ['Visit note'],
          supportNoteBreakdown: 'Support note body',
        ),
      ],
      settings: const AppSettings(),
    );

    expect(folder.id, 'invoices/Invoice 24 Total - 2026-06-01 to 2026-06-14');
    expect(
      driveService.uploads.map((upload) => upload.name),
      containsAll([
        'Invoice_24_2026-06-01_2026-06-14.pdf',
        'Invoice_Total_Breakdown_24_2026-06-01_2026-06-14.docx',
        '2026-06-02_AB_Home_Visit_AB_incomplete.docx',
      ]),
    );

    final supportNoteUpload = driveService.uploads.singleWhere(
      (upload) => upload.name == '2026-06-02_AB_Home_Visit_AB_incomplete.docx',
    );

    expect(_docxText(supportNoteUpload.bytes), contains('Support note body'));

    final breakdownUpload = driveService.uploads.singleWhere(
      (upload) =>
          upload.name ==
          'Invoice_Total_Breakdown_24_2026-06-01_2026-06-14.docx',
    );
    final breakdownText = _docxText(breakdownUpload.bytes);

    expect(breakdownText, contains('Attendance'));
    expect(breakdownText, contains('What happened'));
    expect(breakdownText, contains('Work/task completed'));
    expect(breakdownText, contains('Support given'));
    expect(breakdownText, contains('Issue/problem'));
    expect(breakdownText, contains('Outcome'));
    expect(breakdownText, contains('Next step'));
    expect(breakdownText, contains('Anything to follow up'));
    expect(breakdownText, contains('Referrals'));
    expect(breakdownText, contains('Template for reporting'));
    expect(breakdownText, contains('Main topic(s)'));
    expect(breakdownText, contains('Outcome(s)'));
    expect(breakdownText, contains('Next actions'));
    expect(breakdownText, contains('Overall impression'));
  });
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
    String? contentMimeType,
  }) async {
    uploads.add(
      _DriveUpload(
        parentId: parentId,
        name: name,
        mimeType: mimeType,
        contentMimeType: contentMimeType,
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
    required this.contentMimeType,
    required this.bytes,
  });

  final String parentId;
  final String name;
  final String mimeType;
  final String? contentMimeType;
  final List<int> bytes;
}
