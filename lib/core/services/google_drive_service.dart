import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/personal_log_metrics.dart';
import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/google_drive_file.dart';
import '../models/personal_log_entry.dart';
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
    required this.personalNotesFolder,
  });

  final GoogleDriveFile rootFolder;
  final GoogleDriveFile templatesFolder;
  final GoogleDriveFile clientNotesFolder;
  final GoogleDriveFile calendarExportsFolder;
  final GoogleDriveFile invoicesFolder;
  final GoogleDriveFile referralsFolder;
  final GoogleDriveFile personalNotesFolder;

  AppSettings applyTo(AppSettings settings) {
    return settings.copyWith(
      googleDriveRootFolderId: rootFolder.id,
      googleDriveTemplatesFolderId: templatesFolder.id,
      googleDriveClientNotesFolderId: clientNotesFolder.id,
      googleDriveCalendarExportsFolderId: calendarExportsFolder.id,
      googleDriveInvoicesFolderId: invoicesFolder.id,
      googleDriveReferralsFolderId: referralsFolder.id,
      googleDrivePersonalNotesFolderId: personalNotesFolder.id,
    );
  }
}

class GoogleDrivePersonalFolderSetup {
  const GoogleDrivePersonalFolderSetup({
    required this.rootFolder,
    required this.personalNotesFolder,
  });

  final GoogleDriveFile rootFolder;
  final GoogleDriveFile personalNotesFolder;

  AppSettings applyTo(AppSettings settings) {
    return settings.copyWith(
      personalGoogleDriveRootFolderId: rootFolder.id,
      personalGoogleDrivePersonalNotesFolderId: personalNotesFolder.id,
    );
  }
}

class GoogleDrivePayeFolderSetup {
  const GoogleDrivePayeFolderSetup({
    required this.rootFolder,
    required this.notesFolder,
  });

  final GoogleDriveFile rootFolder;
  final GoogleDriveFile notesFolder;

  AppSettings applyTo(AppSettings settings) {
    return settings.copyWith(
      payeGoogleDriveRootFolderId: rootFolder.id,
      payeGoogleDriveNotesFolderId: notesFolder.id,
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
    this.googleAccountEmail,
  });

  static const googleDocsMimeType = 'application/vnd.google-apps.document';
  static const stableContentFormat = 'drive-docx-v2';

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
  final String? googleAccountEmail;

  String? get openLink {
    final link = webViewLink?.trim();
    if (link != null && link.isNotEmpty) return link;

    final id = fileId.trim();
    if (id.isEmpty) return null;

    final encodedId = Uri.encodeComponent(id);
    if (mimeType == googleDocsMimeType) {
      return 'https://docs.google.com/document/d/$encodedId/edit';
    }

    return 'https://drive.google.com/file/d/$encodedId/view';
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
    String? googleAccountEmail,
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
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
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
      'googleAccountEmail': googleAccountEmail,
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
      googleAccountEmail: json['googleAccountEmail'] as String?,
    );
  }
}

class GoogleDriveService {
  GoogleDriveService({GoogleDriveApiPlatform? api})
    : _api = api ?? GoogleDriveApiPlatform();

  final GoogleDriveApiPlatform _api;
  static const String _googleDocsMimeType =
      'application/vnd.google-apps.document';
  static const String _docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
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

  Future<void> removeSupportNoteMeta(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_supportNoteMetaKey(entryId));
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

    final periodFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: clientFolder.id,
      name: _cycleFolderName(invoiceNumber: invoiceNumber, range: range),
    );

    return findOrCreateFolder(
      accessToken: accessToken,
      parentId: periodFolder.id,
      name: _supportNoteTypeFolderName(entry.type),
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
    final personalNotes = await _api.createFolder(
      accessToken: accessToken,
      name: 'Personal Notes',
      parentId: root.id,
    );

    return GoogleDriveFolderSetup(
      rootFolder: root,
      templatesFolder: templates,
      clientNotesFolder: clientNotes,
      calendarExportsFolder: calendarExports,
      invoicesFolder: invoices,
      referralsFolder: referrals,
      personalNotesFolder: personalNotes,
    );
  }

  Future<GoogleDrivePersonalFolderSetup> createPersonalFolderSetup({
    required String accessToken,
  }) async {
    final root = await _api.createFolder(
      accessToken: accessToken,
      name: 'Support Worker Log - Personal',
    );
    final personalNotes = await _api.createFolder(
      accessToken: accessToken,
      name: 'Personal Notes',
      parentId: root.id,
    );

    return GoogleDrivePersonalFolderSetup(
      rootFolder: root,
      personalNotesFolder: personalNotes,
    );
  }

  Future<GoogleDrivePayeFolderSetup> createPayeFolderSetup({
    required String accessToken,
  }) async {
    final root = await _api.createFolder(
      accessToken: accessToken,
      name: 'Support Worker Log - PAYE',
    );
    final notes = await _api.createFolder(
      accessToken: accessToken,
      name: 'PAYE Notes',
      parentId: root.id,
    );

    return GoogleDrivePayeFolderSetup(rootFolder: root, notesFolder: notes);
  }

  Future<void> syncPersonalLogEntries({
    required String accessToken,
    required String personalNotesFolderId,
    required List<PersonalLogEntry> entries,
  }) async {
    final moodVoiceNotes = entries
        .where((entry) => entry.metric == moodVoiceNoteMetric)
        .toList();
    final otherEntries = entries
        .where((entry) => entry.metric != moodVoiceNoteMetric)
        .toList();

    if (moodVoiceNotes.isNotEmpty) {
      final healthFolder = await findOrCreateFolder(
        accessToken: accessToken,
        parentId: personalNotesFolderId,
        name: _personalCategoryFolderName(PersonalLogCategory.health),
      );
      final bytes = LocalSupportNoteService.buildMoodVoiceNotesDocx(
        entries: moodVoiceNotes,
      );

      await uploadOrUpdateFile(
        accessToken: accessToken,
        parentId: healthFolder.id,
        name: 'Mood Voice Notes',
        mimeType: _googleDocsMimeType,
        bytes: bytes,
        contentMimeType: _docxMimeType,
      );
    }

    for (final entry in otherEntries) {
      final folder = await _personalLogFolder(
        accessToken: accessToken,
        personalNotesFolderId: personalNotesFolderId,
        entry: entry,
      );
      final bytes = await LocalSupportNoteService.buildPersonalLogDocx(
        entry: entry,
      );

      await uploadOrUpdateFile(
        accessToken: accessToken,
        parentId: folder.id,
        name: _personalLogFileName(entry),
        mimeType: _docxMimeType,
        bytes: bytes,
      );
    }
  }

  Future<GoogleDriveFile> savePayeNote({
    required String accessToken,
    required String notesFolderId,
    required WorkEntry entry,
    bool temporary = false,
  }) async {
    final personFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: notesFolderId,
      name: _folderName(entry.client),
    );
    final yearFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: personFolder.id,
      name: entry.date.year.toString(),
    );
    final bytes = LocalSupportNoteService.buildPayeNoteDocx(entry: entry);

    return uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: yearFolder.id,
      name: temporary
          ? _temporaryPayeNoteGoogleDocName(entry)
          : _payeNoteGoogleDocName(entry),
      mimeType: _googleDocsMimeType,
      bytes: bytes,
      contentMimeType: _docxMimeType,
    );
  }

  Future<void> deleteFile({
    required String accessToken,
    required String fileId,
  }) {
    return _api.deleteFile(accessToken: accessToken, fileId: fileId);
  }

  Future<EntryDriveSupportNoteMeta?> findSupportNoteInDrive({
    required String accessToken,
    required String clientNotesFolderId,
    required WorkEntry entry,
    DateTime? payPeriodAnchorDate,
    String? googleAccountEmail,
  }) async {
    final folder = await _findExistingSupportNoteFolder(
      accessToken: accessToken,
      clientNotesFolderId: clientNotesFolderId,
      entry: entry,
      payPeriodAnchorDate: payPeriodAnchorDate,
    );
    if (folder == null) return null;

    final files = await listFolder(
      accessToken: accessToken,
      folderId: folder.id,
    );
    final datePrefix = '${_dateKey(entry.date)}_';
    final matches =
        files
            .where(
              (file) =>
                  file.name.startsWith(datePrefix) &&
                  (file.mimeType == _docxMimeType ||
                      file.mimeType == _googleDocsMimeType),
            )
            .toList()
          ..sort((a, b) => b.name.compareTo(a.name));

    if (matches.isEmpty) return null;

    final file = matches.first;
    return EntryDriveSupportNoteMeta(
      entryId: entry.id,
      initials: LocalSupportNoteService.personNameForEntry(entry),
      status: _statusFromSupportNoteFileName(file.name),
      fileId: file.id,
      fileName: file.name,
      noteText: '',
      mimeType: file.mimeType,
      parentFolderId: folder.id,
      webViewLink: file.webViewLink,
      contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
      googleAccountEmail: googleAccountEmail?.trim(),
    );
  }

  Future<EntryDriveSupportNoteMeta?> findPayeNoteInDrive({
    required String accessToken,
    required String notesFolderId,
    required WorkEntry entry,
    String? googleAccountEmail,
  }) async {
    final matches = await findPayeNotesInDrive(
      accessToken: accessToken,
      notesFolderId: notesFolderId,
      entry: entry,
      googleAccountEmail: googleAccountEmail,
    );

    if (matches.isEmpty) return null;

    return matches.first;
  }

  Future<List<EntryDriveSupportNoteMeta>> findPayeNotesInDrive({
    required String accessToken,
    required String notesFolderId,
    required WorkEntry entry,
    String? googleAccountEmail,
  }) async {
    final personFolder = await _findChild(
      accessToken: accessToken,
      parentId: notesFolderId,
      name: _folderName(entry.client),
      mimeType: 'application/vnd.google-apps.folder',
    );
    if (personFolder == null) return const [];

    final yearFolder = await _findChild(
      accessToken: accessToken,
      parentId: personFolder.id,
      name: entry.date.year.toString(),
      mimeType: 'application/vnd.google-apps.folder',
    );
    if (yearFolder == null) return const [];

    final files = await listFolder(
      accessToken: accessToken,
      folderId: yearFolder.id,
    );
    final googleDocName = _payeNoteGoogleDocName(entry);
    final docxName = _payeNoteFileName(entry);

    return files
        .where(
          (file) =>
              (file.name == googleDocName &&
                  file.mimeType == _googleDocsMimeType) ||
              (file.name == docxName && file.mimeType == _docxMimeType),
        )
        .map(
          (file) => EntryDriveSupportNoteMeta(
            entryId: entry.id,
            initials: LocalSupportNoteService.personNameForEntry(entry),
            status: EntrySupportNoteStatus.submitted,
            fileId: file.id,
            fileName: file.name,
            noteText: '',
            mimeType: file.mimeType,
            parentFolderId: yearFolder.id,
            webViewLink: file.webViewLink,
            contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
            googleAccountEmail: googleAccountEmail?.trim(),
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.mimeType == b.mimeType) return a.fileName.compareTo(b.fileName);
        return a.mimeType == _googleDocsMimeType ? -1 : 1;
      });
  }

  Future<GoogleDriveFile> _personalLogFolder({
    required String accessToken,
    required String personalNotesFolderId,
    required PersonalLogEntry entry,
  }) async {
    final categoryFolder = await findOrCreateFolder(
      accessToken: accessToken,
      parentId: personalNotesFolderId,
      name: _personalCategoryFolderName(entry.category),
    );

    if (entry.category == PersonalLogCategory.gym) {
      final parts = _personalGymTitleParts(entry.title);
      final splitFolder = await findOrCreateFolder(
        accessToken: accessToken,
        parentId: categoryFolder.id,
        name: parts.splitName,
      );
      final exerciseFolder = await findOrCreateFolder(
        accessToken: accessToken,
        parentId: splitFolder.id,
        name: parts.exerciseName,
      );

      return findOrCreateFolder(
        accessToken: accessToken,
        parentId: exerciseFolder.id,
        name: entry.date.year.toString(),
      );
    }

    return findOrCreateFolder(
      accessToken: accessToken,
      parentId: categoryFolder.id,
      name: entry.date.year.toString(),
    );
  }

  Future<GoogleDriveFile?> _findExistingSupportNoteFolder({
    required String accessToken,
    required String clientNotesFolderId,
    required WorkEntry entry,
    DateTime? payPeriodAnchorDate,
  }) async {
    final range = fortnightForDate(entry.date, anchorDate: payPeriodAnchorDate);
    final invoiceNumber = await InvoicePdfService.invoiceNumberForPeriod(range);
    final clientFolder = await _findChild(
      accessToken: accessToken,
      parentId: clientNotesFolderId,
      name: _folderName(entry.client),
      mimeType: 'application/vnd.google-apps.folder',
    );
    if (clientFolder == null) return null;

    final periodFolder =
        await _findChild(
          accessToken: accessToken,
          parentId: clientFolder.id,
          name: _cycleFolderName(invoiceNumber: invoiceNumber, range: range),
          mimeType: 'application/vnd.google-apps.folder',
        ) ??
        await _findSupportNotePeriodFolderFallback(
          accessToken: accessToken,
          clientFolderId: clientFolder.id,
          entry: entry,
        );
    if (periodFolder == null) return null;

    return _findChild(
      accessToken: accessToken,
      parentId: periodFolder.id,
      name: _supportNoteTypeFolderName(entry.type),
      mimeType: 'application/vnd.google-apps.folder',
    );
  }

  Future<GoogleDriveFile?> _findSupportNotePeriodFolderFallback({
    required String accessToken,
    required String clientFolderId,
    required WorkEntry entry,
  }) async {
    final periodFolders = await listFolder(
      accessToken: accessToken,
      folderId: clientFolderId,
    );
    final typeFolderName = _supportNoteTypeFolderName(entry.type);

    for (final folder in periodFolders) {
      if (folder.mimeType != 'application/vnd.google-apps.folder') continue;

      final typeFolder = await _findChild(
        accessToken: accessToken,
        parentId: folder.id,
        name: typeFolderName,
        mimeType: 'application/vnd.google-apps.folder',
      );
      if (typeFolder == null) continue;

      final files = await listFolder(
        accessToken: accessToken,
        folderId: typeFolder.id,
      );
      final datePrefix = '${_dateKey(entry.date)}_';
      final hasMatchingFile = files.any(
        (file) =>
            file.name.startsWith(datePrefix) &&
            (file.mimeType == _docxMimeType ||
                file.mimeType == _googleDocsMimeType),
      );
      if (hasMatchingFile) return folder;
    }

    return null;
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
    String? googleAccountEmail,
  }) async {
    final cleanedInitials = LocalSupportNoteService.personNameForEntry(
      entry,
      fallback: initials,
    );

    if (cleanedInitials.isEmpty) {
      throw StateError('Enter person name first.');
    }

    final displayEntry = entry.copyWith(client: cleanedInitials);
    final driveFileName = _supportNoteDriveFileName(displayEntry, status);
    final periodFolder = await findOrCreateSupportNoteFolder(
      accessToken: accessToken,
      clientNotesFolderId: clientNotesFolderId,
      entry: displayEntry,
      payPeriodAnchorDate: payPeriodAnchorDate,
    );
    final bytes = await LocalSupportNoteService.buildNoteDocx(
      entry: displayEntry,
      initials: cleanedInitials,
      status: status,
      noteText: noteText,
      clientDisplayName: _folderName(displayEntry.client),
    );
    final existingFileId = existingMeta?.fileId.trim();
    final existingParentFolderId = existingMeta?.parentFolderId?.trim();
    final currentGoogleAccountEmail = googleAccountEmail?.trim();
    final existingGoogleAccountEmail = existingMeta?.googleAccountEmail?.trim();
    final sameGoogleAccount =
        currentGoogleAccountEmail == null ||
        currentGoogleAccountEmail.isEmpty ||
        (existingGoogleAccountEmail != null &&
            existingGoogleAccountEmail.isNotEmpty &&
            existingGoogleAccountEmail.toLowerCase() ==
                currentGoogleAccountEmail.toLowerCase());
    final existingMimeType = existingMeta?.mimeType;
    final canUpdateExistingDriveFile =
        sameGoogleAccount &&
        (existingMimeType == _docxMimeType ||
            existingMimeType == _googleDocsMimeType) &&
        existingFileId != null &&
        existingFileId.isNotEmpty;
    final shouldMoveExistingDriveFile =
        canUpdateExistingDriveFile &&
        existingParentFolderId != null &&
        existingParentFolderId.isNotEmpty &&
        existingParentFolderId != periodFolder.id;
    if (shouldMoveExistingDriveFile) {
      await _api.moveFile(
        accessToken: accessToken,
        fileId: existingFileId,
        fromParentId: existingParentFolderId,
        toParentId: periodFolder.id,
      );
    }

    final isGoogleDoc = existingMimeType == _googleDocsMimeType;
    final file = canUpdateExistingDriveFile
        ? await _api.updateFile(
            accessToken: accessToken,
            fileId: existingFileId,
            name: isGoogleDoc
                ? _supportNoteGoogleDocName(displayEntry, status)
                : driveFileName,
            mimeType: isGoogleDoc ? _googleDocsMimeType : _docxMimeType,
            bytes: bytes,
            contentMimeType: isGoogleDoc ? _docxMimeType : null,
          )
        : await uploadOrUpdateFile(
            accessToken: accessToken,
            parentId: periodFolder.id,
            name: driveFileName,
            mimeType: _docxMimeType,
            bytes: bytes,
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
      googleAccountEmail: currentGoogleAccountEmail,
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

  String _supportNoteTypeFolderName(EntryType type) {
    switch (type) {
      case EntryType.textNote:
        return 'Texts';
      case EntryType.phoneCall:
        return 'Phone Calls';
      case EntryType.videoCall:
        return 'Video Calls';
      case EntryType.emailClient:
        return 'Client Emails';
      case EntryType.emailProfessional:
        return 'Professional Emails';
      case EntryType.adminEducationResources:
        return 'Admin Education Resources';
      case EntryType.homeVisit:
        return 'Home Visits';
      case EntryType.professionalContact:
        return 'Professional Contacts';
    }
  }

  String _personalCategoryFolderName(PersonalLogCategory category) {
    switch (category) {
      case PersonalLogCategory.gym:
        return 'Gym';
      case PersonalLogCategory.bodyWeight:
        return 'Body Weight';
      case PersonalLogCategory.health:
        return 'Health';
      case PersonalLogCategory.goal:
        return 'Goals';
      case PersonalLogCategory.note:
        return 'Notes';
    }
  }

  String _personalLogFileName(PersonalLogEntry entry) {
    final title = _folderName(entry.title).replaceAll(' ', '_');
    return '${_dateKey(entry.date)}_${entry.category.name}_$title.docx';
  }

  String _payeNoteFileName(WorkEntry entry) {
    final person = _folderName(entry.client).replaceAll(' ', '_');
    return '${_dateKey(entry.date)}_$person.docx';
  }

  String _supportNoteDriveFileName(
    WorkEntry entry,
    EntrySupportNoteStatus status,
  ) {
    final person = _folderName(entry.client).replaceAll(' ', '_');
    return '${_dateKey(entry.date)}_${person}_${status.fileSlug}.docx';
  }

  String _supportNoteGoogleDocName(
    WorkEntry entry,
    EntrySupportNoteStatus status,
  ) {
    final fileName = _supportNoteDriveFileName(entry, status);
    return fileName.endsWith('.docx')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
  }

  String _payeNoteGoogleDocName(WorkEntry entry) {
    final fileName = _payeNoteFileName(entry);
    return fileName.endsWith('.docx')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
  }

  String _temporaryPayeNoteGoogleDocName(WorkEntry entry) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'TEST_${_payeNoteGoogleDocName(entry)}_$stamp';
  }

  EntrySupportNoteStatus _statusFromSupportNoteFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('_submitted')) {
      return EntrySupportNoteStatus.submitted;
    }
    if (lower.contains('_finished')) {
      return EntrySupportNoteStatus.finished;
    }
    if (lower.contains('_in-progress')) {
      return EntrySupportNoteStatus.inProgress;
    }
    return EntrySupportNoteStatus.incomplete;
  }

  _PersonalGymTitleParts _personalGymTitleParts(String title) {
    final parts = title.split(':');

    if (parts.length < 2) {
      return _PersonalGymTitleParts(
        splitName: 'General',
        exerciseName: _folderName(title),
      );
    }

    final splitName = _folderName(parts.first);
    final exerciseName = _folderName(parts.sublist(1).join(':'));

    return _PersonalGymTitleParts(
      splitName: splitName,
      exerciseName: exerciseName,
    );
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
      name: 'Referrals Template.txt',
      contents:
          'Referrals\n\n'
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

class _PersonalGymTitleParts {
  const _PersonalGymTitleParts({
    required this.splitName,
    required this.exerciseName,
  });

  final String splitName;
  final String exerciseName;
}

class _TextTemplate {
  const _TextTemplate({required this.name, required this.contents});

  final String name;
  final String contents;
}
