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
    this.mimeType,
    this.parentFolderId,
    this.webViewLink,
    this.contentFormat,
  });

  static const googleDocsMimeType = 'application/vnd.google-apps.document';
  static const stableContentFormat = 'drive-google-docs-from-docx-v1';

  final String entryId;
  final String initials;
  final EntrySupportNoteStatus status;
  final String fileId;
  final String fileName;
  final String noteText;
  final String? mimeType;
  final String? parentFolderId;
  final String? webViewLink;
  final String? contentFormat;

  String? get openLink {
    final id = fileId.trim();
    if (id.isNotEmpty) {
      final encodedId = Uri.encodeComponent(id);
      return 'https://docs.google.com/document/d/$encodedId/edit';
    }

    final link = webViewLink?.trim();
    return link == null || link.isEmpty ? null : link;
  }

  String? get folderOpenLink {
    final id = parentFolderId?.trim();
    if (id == null || id.isEmpty) return null;

    return 'https://drive.google.com/drive/folders/${Uri.encodeComponent(id)}';
  }

  EntryDriveSupportNoteMeta copyWith({
    String? initials,
    EntrySupportNoteStatus? status,
    String? fileId,
    String? fileName,
    String? noteText,
    String? mimeType,
    String? parentFolderId,
    String? webViewLink,
    String? contentFormat,
  }) {
    return EntryDriveSupportNoteMeta(
      entryId: entryId,
      initials: initials ?? this.initials,
      status: status ?? this.status,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      noteText: noteText ?? this.noteText,
      mimeType: mimeType ?? this.mimeType,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      webViewLink: webViewLink ?? this.webViewLink,
      contentFormat: contentFormat ?? this.contentFormat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'initials': initials,
      'status': status.name,
      'fileId': fileId,
      'fileName': fileName,
      'noteText': noteText,
      'mimeType': mimeType,
      'parentFolderId': parentFolderId,
      'webViewLink': webViewLink,
      'contentFormat': contentFormat,
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
      mimeType: json['mimeType'] as String?,
      parentFolderId: json['parentFolderId'] as String?,
      webViewLink: json['webViewLink'] as String?,
      contentFormat: json['contentFormat'] as String?,
    );
  }
}

class GoogleDriveService {
  GoogleDriveService({GoogleDriveApiPlatform? api})
    : _api = api ?? GoogleDriveApiPlatform();

  final GoogleDriveApiPlatform _api;
  static const String _docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  static const String _googleDocsMimeType =
      EntryDriveSupportNoteMeta.googleDocsMimeType;
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

  Future<void> saveSupportNoteMeta(EntryDriveSupportNoteMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _supportNoteMetaKey(meta.entryId),
      jsonEncode(meta.toJson()),
    );
  }

  Future<GoogleDriveFile> findOrCreateSupportNoteFolder({
    required String accessToken,
    required String clientNotesFolderId,
    required WorkEntry entry,
    DateTime? payPeriodAnchorDate,
  }) async {
    final range = fortnightForDate(entry.date, anchorDate: payPeriodAnchorDate);
    final invoiceNumber = await InvoicePdfService.invoiceNumberForPeriod(range);
    final clientFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: clientNotesFolderId,
      name: _folderName(entry.client),
    );

    return findOrCreateFolder(
      accessToken: accessToken,
      parentId: clientFolder.id,
      name: _cycleFolderName(invoiceNumber: invoiceNumber, range: range),
    );
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
        file: await _uploadOrUpdateTemplate(
          accessToken: accessToken,
          parentId: templatesFolderId,
          name: 'TEMPLATE.docx',
          mimeType: _docxMimeType,
          bytes: docxBytes,
        ),
      ),
    );

    for (final template in _textTemplates) {
      uploads.add(
        GoogleDriveTemplateUpload(
          name: template.name,
          file: await _uploadOrUpdateTemplate(
            accessToken: accessToken,
            parentId: templatesFolderId,
            name: template.name,
            mimeType: 'text/plain',
            bytes: utf8.encode(template.contents),
          ),
        ),
      );
    }

    return uploads;
  }

  Future<GoogleDriveFile> _uploadOrUpdateTemplate({
    required String accessToken,
    required String parentId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final existing = await _findChildByName(
      accessToken: accessToken,
      parentId: parentId,
      name: name,
    );

    if (existing == null) {
      return _api.uploadFile(
        accessToken: accessToken,
        name: name,
        mimeType: mimeType,
        bytes: bytes,
        parentId: parentId,
      );
    }

    return _api.updateFile(
      accessToken: accessToken,
      fileId: existing.id,
      name: name,
      mimeType: mimeType,
      bytes: bytes,
    );
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
    String? contentMimeType,
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
        contentMimeType: contentMimeType,
      );
    }

    return _api.updateFile(
      accessToken: accessToken,
      fileId: existing.id,
      name: cleanedName,
      mimeType: mimeType,
      bytes: bytes,
      contentMimeType: contentMimeType,
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

  Future<GoogleDriveFile?> _findChildByName({
    required String accessToken,
    required String parentId,
    required String name,
  }) async {
    final children = await listFolder(
      accessToken: accessToken,
      folderId: parentId,
    );

    for (final child in children) {
      if (child.name == name) return child;
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
    final periodFolder = await findOrCreateSupportNoteFolder(
      accessToken: accessToken,
      clientNotesFolderId: clientNotesFolderId,
      entry: entry,
      payPeriodAnchorDate: payPeriodAnchorDate,
    );
    final bytes = await LocalSupportNoteService.buildNoteDocx(
      entry: entry,
      initials: cleanedInitials,
      status: status,
      noteText: noteText,
    );
    final existingFileId = existingMeta?.fileId.trim();
    final file = existingFileId != null && existingFileId.isNotEmpty
        ? await _api.updateFile(
            accessToken: accessToken,
            fileId: existingFileId,
            name: driveFileName,
            mimeType: _googleDocsMimeType,
            bytes: bytes,
            contentMimeType: _docxMimeType,
          )
        : await uploadOrUpdateFile(
            accessToken: accessToken,
            parentId: periodFolder.id,
            name: driveFileName,
            mimeType: _googleDocsMimeType,
            bytes: bytes,
            contentMimeType: _docxMimeType,
          );

    final meta = EntryDriveSupportNoteMeta(
      entryId: entry.id,
      initials: cleanedInitials,
      status: status,
      fileId: file.id,
      fileName: file.name,
      noteText: noteText,
      mimeType: file.mimeType,
      parentFolderId: periodFolder.id,
      webViewLink: file.webViewLink,
      contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
    );
    await saveSupportNoteMeta(meta);

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
