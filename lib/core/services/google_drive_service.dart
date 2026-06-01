import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/google_drive_file.dart';
import '../models/work_entry.dart';
import '../utils/pay_period_utils.dart';
import 'google_drive/google_drive_api_platform.dart';
import 'invoice_pdf_service.dart';
import 'local_support_note_service.dart';

class GoogleDriveFolderSetup {
  const GoogleDriveFolderSetup({
    required this.rootFolder,
    required this.templatesFolder,
    required this.clientNotesFolder,
    required this.calendarExportsFolder,
    required this.invoicesFolder,
    required this.referralsFolder,
  });

  final GoogleDriveFile rootFolder;
  final GoogleDriveFile templatesFolder;
  final GoogleDriveFile clientNotesFolder;
  final GoogleDriveFile calendarExportsFolder;
  final GoogleDriveFile invoicesFolder;
  final GoogleDriveFile referralsFolder;

  AppSettings applyTo(AppSettings settings) {
    return settings.copyWith(
      googleDriveRootFolderId: rootFolder.id,
      googleDriveTemplatesFolderId: templatesFolder.id,
      googleDriveClientNotesFolderId: clientNotesFolder.id,
      googleDriveCalendarExportsFolderId: calendarExportsFolder.id,
      googleDriveInvoicesFolderId: invoicesFolder.id,
      googleDriveReferralsFolderId: referralsFolder.id,
    );
  }
}

class GoogleDriveTemplateUpload {
  const GoogleDriveTemplateUpload({required this.name, required this.file});

  final String name;
  final GoogleDriveFile file;
}

class EntryDriveSupportNoteMeta {
  const EntryDriveSupportNoteMeta({
    required this.entryId,
    required this.initials,
    required this.status,
    required this.fileId,
    required this.fileName,
    required this.noteText,
    this.parentFolderId,
    this.webViewLink,
  });

  final String entryId;
  final String initials;
  final EntrySupportNoteStatus status;
  final String fileId;
  final String fileName;
  final String noteText;
  final String? parentFolderId;
  final String? webViewLink;

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'initials': initials,
      'status': status.name,
      'fileId': fileId,
      'fileName': fileName,
      'noteText': noteText,
      'parentFolderId': parentFolderId,
      'webViewLink': webViewLink,
    };
  }

  factory EntryDriveSupportNoteMeta.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final status = EntrySupportNoteStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => EntrySupportNoteStatus.incomplete,
    );

    return EntryDriveSupportNoteMeta(
      entryId: json['entryId'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      status: status,
      fileId: json['fileId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      noteText: json['noteText'] as String? ?? '',
      parentFolderId: json['parentFolderId'] as String?,
      webViewLink: json['webViewLink'] as String?,
    );
  }
}

class GoogleDriveService {
  GoogleDriveService({GoogleDriveApiPlatform? api})
    : _api = api ?? GoogleDriveApiPlatform();

  final GoogleDriveApiPlatform _api;

  static String _supportNoteMetaKey(String entryId) {
    return 'entry_google_drive_support_note_$entryId';
  }

  Future<EntryDriveSupportNoteMeta?> loadSupportNoteMeta(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_supportNoteMetaKey(entryId));

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EntryDriveSupportNoteMeta.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<GoogleDriveFolderSetup> createFolderSetup({
    required String accessToken,
  }) async {
    final root = await _api.createFolder(
      accessToken: accessToken,
      name: 'Support Worker Log',
    );
    final templates = await _api.createFolder(
      accessToken: accessToken,
      name: 'Templates',
      parentId: root.id,
    );
    final clientNotes = await _api.createFolder(
      accessToken: accessToken,
      name: 'Client Notes',
      parentId: root.id,
    );
    final calendarExports = await _api.createFolder(
      accessToken: accessToken,
      name: 'Calendar Exports',
      parentId: root.id,
    );
    final invoices = await _api.createFolder(
      accessToken: accessToken,
      name: 'Invoices',
      parentId: root.id,
    );
    final referrals = await _api.createFolder(
      accessToken: accessToken,
      name: 'Referrals',
      parentId: root.id,
    );

    return GoogleDriveFolderSetup(
      rootFolder: root,
      templatesFolder: templates,
      clientNotesFolder: clientNotes,
      calendarExportsFolder: calendarExports,
      invoicesFolder: invoices,
      referralsFolder: referrals,
    );
  }

  Future<List<GoogleDriveTemplateUpload>> uploadDefaultTemplates({
    required String accessToken,
    required String templatesFolderId,
  }) async {
    final uploads = <GoogleDriveTemplateUpload>[];
    final docxData = await rootBundle.load('assets/templates/TEMPLATE.docx');
    final docxBytes = docxData.buffer.asUint8List(
      docxData.offsetInBytes,
      docxData.lengthInBytes,
    );

    uploads.add(
      GoogleDriveTemplateUpload(
        name: 'TEMPLATE.docx',
        file: await _api.uploadFile(
          accessToken: accessToken,
          name: 'TEMPLATE.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          bytes: docxBytes,
          parentId: templatesFolderId,
        ),
      ),
    );

    for (final template in _textTemplates) {
      uploads.add(
        GoogleDriveTemplateUpload(
          name: template.name,
          file: await _api.uploadFile(
            accessToken: accessToken,
            name: template.name,
            mimeType: 'text/plain',
            bytes: utf8.encode(template.contents),
            parentId: templatesFolderId,
          ),
        ),
      );
    }

    return uploads;
  }

  Future<List<GoogleDriveFile>> listFolder({
    required String accessToken,
    required String folderId,
  }) {
    return _api.listChildren(accessToken: accessToken, parentId: folderId);
  }

  Future<GoogleDriveFile> findOrCreateFolder({
    required String accessToken,
    required String parentId,
    required String name,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw StateError('Google Drive folder name cannot be empty.');
    }

    final existing = await _findChild(
      accessToken: accessToken,
      parentId: parentId,
      name: cleanedName,
      mimeType: 'application/vnd.google-apps.folder',
    );

    if (existing != null) return existing;

    return _api.createFolder(
      accessToken: accessToken,
      name: cleanedName,
      parentId: parentId,
    );
  }

  Future<GoogleDriveFile> uploadOrUpdateFile({
    required String accessToken,
    required String parentId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw StateError('Google Drive file name cannot be empty.');
    }

    final existing = await _findChild(
      accessToken: accessToken,
      parentId: parentId,
      name: cleanedName,
      mimeType: mimeType,
    );

    if (existing == null) {
      return _api.uploadFile(
        accessToken: accessToken,
        name: cleanedName,
        mimeType: mimeType,
        bytes: bytes,
        parentId: parentId,
      );
    }

    return _api.updateFile(
      accessToken: accessToken,
      fileId: existing.id,
      name: cleanedName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  Future<GoogleDriveFile?> _findChild({
    required String accessToken,
    required String parentId,
    required String name,
    required String mimeType,
  }) async {
    final children = await listFolder(
      accessToken: accessToken,
      folderId: parentId,
    );

    for (final child in children) {
      if (child.name == name && child.mimeType == mimeType) {
        return child;
      }
    }

    return null;
  }

  Future<EntryDriveSupportNoteMeta> saveSupportNote({
    required String accessToken,
    required String clientNotesFolderId,
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
    required String noteText,
    DateTime? payPeriodAnchorDate,
    EntryDriveSupportNoteMeta? existingMeta,
  }) async {
    final cleanedInitials = initials.trim().toUpperCase();

    if (cleanedInitials.isEmpty) {
      throw StateError('Enter initials first.');
    }

    final localFileName = LocalSupportNoteService.noteFileName(
      entry: entry,
      initials: cleanedInitials,
      status: status,
    );
    final driveFileName = localFileName.split('/').last;
    final range = fortnightForDate(entry.date, anchorDate: payPeriodAnchorDate);
    final invoiceNumber = await InvoicePdfService.invoiceNumberForPeriod(range);
    final clientFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: clientNotesFolderId,
      name: _folderName(entry.client),
    );
    final periodFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: clientFolder.id,
      name: _cycleFolderName(invoiceNumber: invoiceNumber, range: range),
    );
    final bytes = await LocalSupportNoteService.buildNoteDocx(
      entry: entry,
      initials: cleanedInitials,
      status: status,
      noteText: noteText,
    );
    const mimeType =
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    final existingFileId = existingMeta?.fileId;
    final canUpdateExisting =
        existingFileId != null &&
        existingFileId.isNotEmpty &&
        existingMeta?.parentFolderId == periodFolder.id;
    final file = !canUpdateExisting
        ? await _api.uploadFile(
            accessToken: accessToken,
            name: driveFileName,
            mimeType: mimeType,
            bytes: bytes,
            parentId: periodFolder.id,
          )
        : await _api.updateFile(
            accessToken: accessToken,
            fileId: existingFileId,
            name: driveFileName,
            mimeType: mimeType,
            bytes: bytes,
          );

    final meta = EntryDriveSupportNoteMeta(
      entryId: entry.id,
      initials: cleanedInitials,
      status: status,
      fileId: file.id,
      fileName: file.name,
      noteText: noteText,
      parentFolderId: periodFolder.id,
      webViewLink: file.webViewLink,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _supportNoteMetaKey(entry.id),
      jsonEncode(meta.toJson()),
    );

    return meta;
  }

  String _folderName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return cleaned.isEmpty ? 'Unknown Client' : cleaned;
  }

  String _cycleFolderName({
    required int invoiceNumber,
    required PayPeriodRange range,
  }) {
    return 'Invoice $invoiceNumber - ${_dateKey(range.start)} to ${_dateKey(range.end)}';
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static const _textTemplates = [
    _TextTemplate(
      name: 'Structured Support Note Template.txt',
      contents: supportNoteBreakdownTemplate,
    ),
    _TextTemplate(
      name: 'Referral Tracking Template.txt',
      contents:
          'Local Referral Tracking\n\n'
          'Police / emergency services:\n'
          'GP / crisis team:\n'
          'Sexual harm services:\n'
          'WINZ / housing / legal / counselling:\n\n'
          'Referral status: made / discussed / declined / pending\n'
          'Consent given:\n'
          'Information shared:\n'
          'Follow-up needed:\n',
    ),
    _TextTemplate(
      name: 'Safety Concerns Template.txt',
      contents:
          'Safety Concerns\n\n'
          'Sexual harm survivor safety concerns:\n'
          'Mental health concerns:\n'
          'Immediate risk identified:\n'
          'Protective actions discussed:\n'
          'Escalation / referral needed:\n'
          'Follow-up timeframe:\n',
    ),
    _TextTemplate(
      name: 'Invoice Folder README.txt',
      contents:
          'Use this folder for generated invoices, pay-period notes, and '
          'timesheet exports from Support Worker Log.\n',
    ),
  ];
}

class _TextTemplate {
  const _TextTemplate({required this.name, required this.contents});

  final String name;
  final String contents;
}
