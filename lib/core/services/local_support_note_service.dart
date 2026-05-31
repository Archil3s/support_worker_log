import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/work_entry.dart';
import '../utils/formatters.dart';
import 'local_support_notes/local_support_notes_platform.dart';

enum EntrySupportNoteStatus { incomplete, inProgress, finished, submitted }

extension EntrySupportNoteStatusLabel on EntrySupportNoteStatus {
  String get label {
    switch (this) {
      case EntrySupportNoteStatus.incomplete:
        return 'Incomplete';
      case EntrySupportNoteStatus.inProgress:
        return 'In Progress';
      case EntrySupportNoteStatus.finished:
        return 'Finished';
      case EntrySupportNoteStatus.submitted:
        return 'Submitted';
    }
  }

  String get fileSlug {
    switch (this) {
      case EntrySupportNoteStatus.incomplete:
        return 'incomplete';
      case EntrySupportNoteStatus.inProgress:
        return 'in-progress';
      case EntrySupportNoteStatus.finished:
        return 'finished';
      case EntrySupportNoteStatus.submitted:
        return 'submitted';
    }
  }
}

class EntrySupportNoteMeta {
  const EntrySupportNoteMeta({
    required this.entryId,
    required this.initials,
    required this.status,
    required this.fileName,
    required this.noteText,
  });

  final String entryId;
  final String initials;
  final EntrySupportNoteStatus status;
  final String fileName;
  final String noteText;

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'initials': initials,
      'status': status.name,
      'fileName': fileName,
      'noteText': noteText,
    };
  }

  factory EntrySupportNoteMeta.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;

    final status = EntrySupportNoteStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => EntrySupportNoteStatus.incomplete,
    );

    return EntrySupportNoteMeta(
      entryId: json['entryId'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      status: status,
      fileName: json['fileName'] as String? ?? '',
      noteText: json['noteText'] as String? ?? '',
    );
  }
}

class LocalSupportNoteService {
  LocalSupportNoteService._();

  static final LocalSupportNotesPlatform _platform =
      LocalSupportNotesPlatform();

  static String _metaKey(String entryId) {
    return 'entry_local_support_note_$entryId';
  }

  static Future<bool> chooseFolder() {
    return _platform.chooseFolder();
  }

  static Future<EntrySupportNoteMeta?> loadMeta(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey(entryId));

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EntrySupportNoteMeta.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<EntrySupportNoteMeta> saveNote({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
    required String noteText,
  }) async {
    final cleanedInitials = initials.trim().toUpperCase();

    if (cleanedInitials.isEmpty) {
      throw StateError('Enter initials first.');
    }

    final existing = await loadMeta(entry.id);

    final fileName = _fileName(
      entry: entry,
      initials: cleanedInitials,
      status: status,
    );

    final docxBytes = _buildBlankTemplateDocx(
      entry: entry,
      initials: cleanedInitials,
    );

    final contents = '__BASE64__:${base64Encode(docxBytes)}';

    if (existing != null && existing.fileName.isNotEmpty) {
      if (existing.fileName != fileName) {
        await _platform.renameFile(
          oldFileName: existing.fileName,
          newFileName: fileName,
          contents: contents,
        );
      } else {
        // Do not overwrite an existing DOCX. The user may have edited it in Word.
      }
    } else {
      await _platform.writeFile(fileName: fileName, contents: contents);
    }

    final meta = EntrySupportNoteMeta(
      entryId: entry.id,
      initials: cleanedInitials,
      status: status,
      fileName: fileName,
      noteText: noteText,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaKey(entry.id), jsonEncode(meta.toJson()));

    return meta;
  }

  static Future<bool> openNote(EntrySupportNoteMeta meta) {
    return _platform.openFile(meta.fileName);
  }

  static String defaultInitialsForEntry(WorkEntry entry) {
    final value = entry.client.trim();

    if (value.isEmpty) return 'NA';

    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.length == 1) {
      final only = parts.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

      if (only.length >= 2) {
        return only.substring(0, 2).toUpperCase();
      }

      return only.toUpperCase();
    }

    return parts
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }

  static String defaultNoteTextForEntry({
    required WorkEntry entry,
    required EntrySupportNoteStatus status,
  }) {
    final savedBreakdown = entry.supportNoteBreakdown.trim();
    final buffer = StringBuffer(
      savedBreakdown.isNotEmpty ? savedBreakdown : supportNoteBreakdownTemplate,
    );

    if (entry.nextActions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Tracked next actions');

      for (final action in entry.nextActions) {
        final completedText = action.completedAt == null
            ? 'open'
            : 'completed ${formatDate(action.completedAt!)} '
                  '${_clock(action.completedAt!)}';

        buffer.writeln('- ${action.text} ($completedText)');
      }
    }

    return buffer.toString().trim();
  }

  static String noteTitle({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
  }) {
    return '${initials.trim().toUpperCase()} | ${status.label} | ${formatDate(entry.date)}';
  }

  static String _fileName({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
  }) {
    final date = _fileDate(entry.date);
    final statusPart = _safeFilePart(status.fileSlug);
    final cleanInitials = _safeFilePart(initials).toUpperCase();

    return '$cleanInitials/${date}_${cleanInitials}_$statusPart.docx';
  }

  static List<int> _buildBlankTemplateDocx({
    required WorkEntry entry,
    required String initials,
  }) {
    final visitDate = formatDate(entry.date);
    final cleanInitials = initials.trim().toUpperCase();

    final paragraphs = <_DocxParagraph>[
      const _DocxParagraph(
        'Template for reporting of interactions with survivors.',
        bold: true,
        center: true,
        size: 28,
      ),
      const _DocxParagraph(''),
      const _DocxParagraph(
        'This template is aimed at providing information in a format that meets the requirements of the Ministry of Social Development.',
      ),
      const _DocxParagraph(''),
      const _DocxParagraph('Geographical area. Blenheim'),
      const _DocxParagraph(''),
      _DocxParagraph('Date: $visitDate'),
      const _DocxParagraph(''),
      _DocxParagraph('Name of client. $cleanInitials'),
      const _DocxParagraph(''),
      const _DocxParagraph(
        'Date/time/length of interaction. Also record calls and texts, just time spent on each, no need for non important calls and texts. Record travel time.',
      ),
      const _DocxParagraph(''),
      const _DocxParagraph('Main topic(s)  (max. 200 words)'),
      const _DocxParagraph('1. ', leftIndentTwips: 720),
      const _DocxParagraph('Outcome(s)  (Max. 100 words)'),
      const _DocxParagraph('1. ', leftIndentTwips: 720),
      const _DocxParagraph('Overall impression (Max. 150 words)'),
      const _DocxParagraph('1. ', leftIndentTwips: 720),
    ];

    final archive = Archive();

    void addTextFile(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addTextFile('[Content_Types].xml', _contentTypesXml);
    addTextFile('_rels/.rels', _relsXml);
    addTextFile('word/document.xml', _documentXml(paragraphs));
    addTextFile('word/styles.xml', _stylesXml);
    addTextFile('word/settings.xml', _settingsXml);
    addTextFile('word/_rels/document.xml.rels', _documentRelsXml);

    return ZipEncoder().encode(archive) ?? <int>[];
  }

  static String _documentXml(List<_DocxParagraph> paragraphs) {
    final body = paragraphs.map(_paragraphXml).join();

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }

  static String _paragraphXml(_DocxParagraph paragraph) {
    final paragraphProps = StringBuffer();

    if (paragraph.center) {
      paragraphProps.write('<w:jc w:val="center"/>');
    }

    if (paragraph.leftIndentTwips != null) {
      paragraphProps.write('<w:ind w:left="${paragraph.leftIndentTwips}"/>');
    }

    final runProps = StringBuffer();

    if (paragraph.bold) {
      runProps.write('<w:b/>');
    }

    if (paragraph.size != null) {
      runProps.write('<w:sz w:val="${paragraph.size}"/>');
    }

    final lines = paragraph.text.split('\n');

    final textXml = lines
        .map((line) => '<w:t xml:space="preserve">${_xml(line)}</w:t>')
        .join('<w:br/>');

    return '''
<w:p>
  <w:pPr>$paragraphProps</w:pPr>
  <w:r>
    <w:rPr>$runProps</w:rPr>
    $textXml
  </w:r>
</w:p>
''';
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _fileDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String _clock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  static String _safeFilePart(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return cleaned.isEmpty ? 'note' : cleaned;
  }
}

class _DocxParagraph {
  const _DocxParagraph(
    this.text, {
    this.bold = false,
    this.center = false,
    this.size,
    this.leftIndentTwips,
  });

  final String text;
  final bool bold;
  final bool center;
  final int? size;
  final int? leftIndentTwips;
}

const String _contentTypesXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

const String _relsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

const String _documentRelsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';

const String _stylesXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
</w:styles>''';

const String _settingsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:zoom w:percent="100"/>
</w:settings>''';
