import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry_type.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import 'local_support_notes/local_support_notes_platform.dart';
import '../models/personal_log_entry.dart';

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

    final fileName = noteFileName(
      entry: entry,
      initials: cleanedInitials,
      status: status,
    );

    final docxBytes = await buildNoteDocx(
      entry: entry,
      initials: cleanedInitials,
      status: status,
      noteText: noteText,
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
        await _platform.writeFile(fileName: fileName, contents: contents);
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

  static Future<EntrySupportNoteMeta> savePayeNote({
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
    final fileName = noteFileName(
      entry: entry,
      initials: cleanedInitials,
      status: status,
    );
    final docxBytes = buildPayeNoteDocx(
      entry: entry.copyWith(supportNoteBreakdown: noteText),
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
        await _platform.writeFile(fileName: fileName, contents: contents);
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
    return savedBreakdown.isNotEmpty
        ? savedBreakdown
        : supportNoteBreakdownTemplate;
  }

  static String defaultPayeNoteTextForEntry(WorkEntry entry) {
    final savedBreakdown = entry.supportNoteBreakdown.trim();
    if (savedBreakdown.isNotEmpty) return savedBreakdown;

    return '''
Attendance

Main topic(s)

Outcome(s)

Next action(s)

Overall impression

Local referral tracking

Safety concerns
'''
        .trim();
  }

  static String noteTitle({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
  }) {
    return '${initials.trim().toUpperCase()} | ${formatDate(entry.date)} | ${status.label}';
  }

  static String noteFileName({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
  }) {
    final date = _fileDate(entry.date);
    final statusPart = _safeFilePart(status.fileSlug);
    final cleanInitials = _safeFilePart(initials).toUpperCase();

    return '$cleanInitials/${date}_${cleanInitials}_$statusPart.docx';
  }

  static Future<List<int>> buildNoteDocx({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
    required String noteText,
  }) async {
    try {
      final data = await rootBundle.load('assets/templates/TEMPLATE.docx');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return _docxFromTemplate(
        bytes: bytes,
        clientInitials: initials.trim().toUpperCase(),
        dateText: formatDate(entry.date),
        interactionText:
            '${formatDate(entry.date)} / ${formatTime(entry.startTime)} / '
            '${entry.baseMinutes} minutes '
            '(${entry.hours.toStringAsFixed(2)} hours). '
            '${entry.type.label}.${_kilometresText(entry)}',
        fallbackNoteText: defaultNoteTextForEntry(entry: entry, status: status),
        noteText: noteText,
      );
    } catch (error) {
      throw StateError(
        'Gold-standard support note template could not be loaded: $error',
      );
    }
  }

  static Future<List<int>> buildInvoicePeriodNoteDocx({
    required int invoiceNumber,
    required DateTime start,
    required DateTime end,
    required int entryCount,
    required double hours,
    required double kilometres,
    required String noteText,
    String? title,
  }) async {
    try {
      final data = await rootBundle.load('assets/templates/TEMPLATE.docx');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      return _docxFromTemplate(
        bytes: bytes,
        clientInitials: title ?? 'Invoice $invoiceNumber',
        dateText: '${formatDate(start)} - ${formatDate(end)}',
        interactionText:
            'Invoice period ${formatDate(start)} - ${formatDate(end)}. '
            '$entryCount entries. ${hours.toStringAsFixed(2)} hours. '
            '${kilometres.toStringAsFixed(1)} kilometres.',
        fallbackNoteText: supportNoteBreakdownTemplate,
        noteText: noteText,
      );
    } catch (error) {
      throw StateError(
        'Gold-standard support note template could not be loaded: $error',
      );
    }
  }

  static Future<List<int>> buildPersonalLogDocx({
    required PersonalLogEntry entry,
  }) async {
    try {
      return _personalLogDocx(entry);
    } catch (error) {
      throw StateError('Personal note template could not be loaded: $error');
    }
  }

  static List<int> buildPayeNoteDocx({required WorkEntry entry}) {
    final archive = Archive();

    void addTextFile(String name, String contents) {
      final bytes = utf8.encode(contents);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addTextFile('[Content_Types].xml', _personalContentTypesXml);
    addTextFile('_rels/.rels', _personalRootRelationshipsXml);
    addTextFile('docProps/app.xml', _personalAppPropertiesXml);
    addTextFile('docProps/core.xml', _payeCorePropertiesXml(entry));
    addTextFile('word/document.xml', _payeDocumentXml(entry));

    return ZipEncoder().encode(archive) ?? <int>[];
  }

  static List<int> _personalLogDocx(PersonalLogEntry entry) {
    final archive = Archive();

    void addTextFile(String name, String contents) {
      final bytes = utf8.encode(contents);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addTextFile('[Content_Types].xml', _personalContentTypesXml);
    addTextFile('_rels/.rels', _personalRootRelationshipsXml);
    addTextFile('docProps/app.xml', _personalAppPropertiesXml);
    addTextFile('docProps/core.xml', _personalCorePropertiesXml(entry));
    addTextFile('word/document.xml', _personalDocumentXml(entry));

    return ZipEncoder().encode(archive) ?? <int>[];
  }

  static String _personalDocumentXml(PersonalLogEntry entry) {
    final sections = _personalLogSections(entry);
    final paragraphs = <String>[
      _personalParagraph('Personal Progress Log', style: 'Title'),
      _personalParagraph(entry.category.label, style: 'Subtitle'),
      _personalParagraph('Date: ${formatDate(entry.date)}', bold: true),
      _personalParagraph('Log: ${_personalTitle(entry)}', bold: true),
      if (entry.metric.trim().isNotEmpty)
        _personalParagraph('Tracked result: ${entry.metric.trim()}'),
      _personalSpacer,
      for (final section in sections) ...[
        _personalParagraph(section.title, style: 'Heading1'),
        _personalParagraph(section.body),
        _personalSpacer,
      ],
    ].join();

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $paragraphs
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }

  static String _payeDocumentXml(WorkEntry entry) {
    final sections = _PayeSupportSections.fromEntry(entry);
    final paragraphs = <String>[
      for (final section in sections) ...[
        _personalParagraph(section.title, style: 'Heading1'),
        _personalParagraph(_blankIfEmpty(section.body)),
        _personalSpacer,
      ],
    ].join();

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $paragraphs
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }

  static List<_PersonalLogSection> _personalLogSections(
    PersonalLogEntry entry,
  ) {
    final metric = entry.metric.trim();
    final notes = entry.notes.trim();

    switch (entry.category) {
      case PersonalLogCategory.gym:
        return [
          _PersonalLogSection('Workout', _personalTitle(entry)),
          _PersonalLogSection('Sets, reps, and load', _blankIfEmpty(metric)),
          _PersonalLogSection('Performance notes', _blankIfEmpty(notes)),
          const _PersonalLogSection('Next target', 'Weight:\nReps:\nForm cue:'),
          const _PersonalLogSection(
            'Recovery notes',
            'Energy:\nSleep:\nSoreness:\nPain or niggles:',
          ),
        ];
      case PersonalLogCategory.bodyWeight:
        return [
          _PersonalLogSection('Body weight', _blankIfEmpty(metric)),
          _PersonalLogSection('Check-in notes', _blankIfEmpty(notes)),
          const _PersonalLogSection(
            'Context',
            'Time weighed:\nHydration:\nTraining day:\nTrend note:',
          ),
        ];
      case PersonalLogCategory.health:
        return [
          _PersonalLogSection('Health focus', _personalTitle(entry)),
          _PersonalLogSection('Tracked measure', _blankIfEmpty(metric)),
          _PersonalLogSection('Notes', _blankIfEmpty(notes)),
          const _PersonalLogSection(
            'Next check-in',
            'What to monitor:\nWhat to change:\nReview date:',
          ),
        ];
      case PersonalLogCategory.goal:
        return [
          _PersonalLogSection('Goal', _personalTitle(entry)),
          _PersonalLogSection('Progress measure', _blankIfEmpty(metric)),
          _PersonalLogSection('Progress notes', _blankIfEmpty(notes)),
          const _PersonalLogSection(
            'Next step',
            'Small next action:\nDeadline:\nBlocker:',
          ),
        ];
      case PersonalLogCategory.note:
        return [
          _PersonalLogSection('Topic', _personalTitle(entry)),
          _PersonalLogSection('Detail', _blankIfEmpty(notes)),
          _PersonalLogSection('Metric or reference', _blankIfEmpty(metric)),
          const _PersonalLogSection('Follow-up', '-'),
        ];
    }
  }

  static String _personalParagraph(
    String text, {
    bool bold = false,
    String? style,
  }) {
    final paragraphProps = switch (style) {
      'Title' =>
        '<w:pPr><w:pStyle w:val="Title"/><w:spacing w:after="180"/></w:pPr>',
      'Subtitle' =>
        '<w:pPr><w:pStyle w:val="Subtitle"/><w:spacing w:after="220"/></w:pPr>',
      'Heading1' =>
        '<w:pPr><w:pStyle w:val="Heading1"/><w:spacing w:before="160" w:after="80"/></w:pPr>',
      _ => '<w:pPr><w:spacing w:after="80"/></w:pPr>',
    };

    return '<w:p>$paragraphProps${_personalRun(text, bold: bold || style != null)}</w:p>';
  }

  static String _personalRun(String text, {bool bold = false}) {
    final escapedLines = text
        .split('\n')
        .map((line) => '<w:t xml:space="preserve">${_xml(line)}</w:t>')
        .join('<w:br/>');
    final runProps = bold
        ? '<w:rPr><w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>'
        : '<w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>';

    return '<w:r>$runProps$escapedLines</w:r>';
  }

  static String _personalCorePropertiesXml(PersonalLogEntry entry) {
    final title = _personalTitle(entry);

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${_xml(title)}</dc:title>
  <dc:subject>Personal ${_xml(entry.category.label)} progress log</dc:subject>
  <dc:creator>Support Worker Log</dc:creator>
  <cp:lastModifiedBy>Support Worker Log</cp:lastModifiedBy>
</cp:coreProperties>
''';
  }

  static String _payeCorePropertiesXml(WorkEntry entry) {
    final title = entry.client.trim().isEmpty ? 'Attendance' : entry.client;

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${_xml(title)}</dc:title>
  <dc:subject>Attendance log</dc:subject>
  <dc:creator>Support Worker Log</dc:creator>
  <cp:lastModifiedBy>Support Worker Log</cp:lastModifiedBy>
</cp:coreProperties>
''';
  }

  static String _personalTitle(PersonalLogEntry entry) {
    final title = entry.title.trim();
    return title.isEmpty ? entry.category.label : title;
  }

  static String _blankIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  static const _personalSpacer =
      '<w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>';

  static const _personalContentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
''';

  static const _personalRootRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static const _personalAppPropertiesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Support Worker Log</Application>
</Properties>
''';

  static List<int> _docxFromTemplate({
    required Uint8List bytes,
    required String clientInitials,
    required String dateText,
    required String interactionText,
    required String fallbackNoteText,
    required String noteText,
  }) {
    final source = ZipDecoder().decodeBytes(bytes);
    final archive = Archive();

    for (final file in source.files) {
      if (!file.isFile) continue;

      if (file.name == 'word/document.xml') {
        final xml = utf8.decode(file.content as List<int>);
        final documentBytes = utf8.encode(
          _filledTemplateDocumentXml(
            xml: xml,
            clientInitials: clientInitials,
            dateText: dateText,
            interactionText: interactionText,
            fallbackNoteText: fallbackNoteText,
            noteText: noteText,
          ),
        );
        archive.addFile(
          ArchiveFile(file.name, documentBytes.length, documentBytes),
        );
      } else {
        final content = file.content as List<int>;
        archive.addFile(ArchiveFile(file.name, content.length, content));
      }
    }

    return ZipEncoder().encode(archive) ?? <int>[];
  }

  static String _filledTemplateDocumentXml({
    required String xml,
    required String clientInitials,
    required String dateText,
    required String interactionText,
    required String fallbackNoteText,
    required String noteText,
  }) {
    final sections = _SupportNoteSections.fromNoteText(
      noteText.trim().isEmpty ? fallbackNoteText : noteText,
    );

    final paragraphPattern = RegExp(r'<w:p(?:\s|>)[\s\S]*?<\/w:p>');
    final paragraphMatches = paragraphPattern.allMatches(xml).toList();
    final hasNextActionsSection = paragraphMatches.any((match) {
      final text = _paragraphText(match.group(0)!).trim().toLowerCase();
      return text.startsWith('next action');
    });
    final buffer = StringBuffer();
    var cursor = 0;
    String? pendingBlankFill;
    var appendSupportChecksAfterFill = false;
    var filledNextActions = false;

    for (final match in paragraphMatches) {
      buffer.write(xml.substring(cursor, match.start));
      var paragraph = match.group(0)!;
      final text = _paragraphText(paragraph).trim();

      if (text.startsWith('Name of client')) {
        paragraph = _replaceParagraphText(
          paragraph,
          'Name of client: $clientInitials',
          bold: true,
        );
      } else if (text.startsWith('Date:')) {
        paragraph = _replaceParagraphText(
          paragraph,
          'Date: $dateText',
          bold: true,
        );
      } else if (text.startsWith('Date/time/length of interaction')) {
        paragraph = _replaceParagraphText(
          paragraph,
          'Date/time/length of interaction: $interactionText',
        );
      } else if (text.startsWith('Main topic')) {
        pendingBlankFill = sections.mainTopic;
      } else if (text.startsWith('Outcome')) {
        pendingBlankFill = hasNextActionsSection
            ? sections.outcomes
            : sections.outcomesWithActions;
      } else if (text.startsWith('Next action')) {
        pendingBlankFill = sections.nextActions;
        appendSupportChecksAfterFill = true;
      } else if (text.startsWith('Overall impression')) {
        pendingBlankFill = sections.overallImpression;
      } else if (pendingBlankFill != null && text.isEmpty) {
        if (pendingBlankFill.isNotEmpty) {
          paragraph = _fillBlankParagraph(paragraph, pendingBlankFill);
        }
        filledNextActions = appendSupportChecksAfterFill;
        pendingBlankFill = null;
      }

      buffer.write(paragraph);
      if (filledNextActions) {
        buffer.write(_supportCheckParagraphs(sections));
        appendSupportChecksAfterFill = false;
        filledNextActions = false;
      }
      cursor = match.end;
    }

    buffer.write(xml.substring(cursor));
    return buffer.toString();
  }

  static String _paragraphText(String paragraphXml) {
    return RegExp(
      r'<w:t[^>]*>(.*?)<\/w:t>',
    ).allMatches(paragraphXml).map((match) => _unxml(match.group(1)!)).join();
  }

  static String _replaceParagraphText(
    String paragraphXml,
    String text, {
    bool bold = false,
  }) {
    final withoutRuns = paragraphXml.replaceAll(
      RegExp(r'<w:r(?:\s|>)[\s\S]*?<\/w:r>'),
      '',
    );

    return withoutRuns.replaceFirst(
      '</w:p>',
      '${_runXml(text, bold: bold)}</w:p>',
    );
  }

  static String _fillBlankParagraph(String paragraphXml, String text) {
    final withoutEmptyRun = paragraphXml.replaceFirst(
      RegExp(r'<w:r><w:rPr>[\s\S]*?<\/w:rPr><\/w:r>'),
      '',
    );

    return withoutEmptyRun.replaceFirst('</w:p>', '${_runXml(text)}</w:p>');
  }

  static String _runXml(String text, {bool bold = false}) {
    final runProps = bold
        ? '<w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="24"/>'
        : '<w:sz w:val="24"/><w:szCs w:val="24"/>';
    final textParts = text
        .split('\n')
        .map((line) => '<w:t xml:space="preserve">${_xml(line)}</w:t>')
        .join('<w:br/>');

    return '<w:r><w:rPr>$runProps</w:rPr>$textParts</w:r>';
  }

  static String _paragraphXml(String text, {bool bold = false}) {
    return '<w:p>${_runXml(text, bold: bold)}</w:p>';
  }

  static String _supportCheckParagraphs(_SupportNoteSections sections) {
    if (!sections.hasSupportChecks) return '';

    final buffer = StringBuffer();

    if (sections.referrals.isNotEmpty) {
      buffer
        ..write(_paragraphXml('Local referral tracking', bold: true))
        ..write(_paragraphXml(sections.referrals));
    }

    if (sections.safetyConcerns.isNotEmpty) {
      buffer
        ..write(
          _paragraphXml(
            'Safety concerns for sexual harm survivors and mental health',
            bold: true,
          ),
        )
        ..write(_paragraphXml(sections.safetyConcerns));
    }

    return buffer.toString();
  }

  static String _kilometresText(WorkEntry entry) {
    if (entry.type != EntryType.homeVisit) return '';
    return ' Kilometres: ${entry.kilometres.toStringAsFixed(1)}.';
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unxml(String value) {
    return value
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }

  static String _fileDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
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

class _PersonalLogSection {
  const _PersonalLogSection(this.title, this.body);

  final String title;
  final String body;
}

class _PayeSupportSections {
  const _PayeSupportSections({
    required this.attendance,
    required this.mainTopic,
    required this.outcomes,
    required this.nextActions,
    required this.impression,
    required this.referrals,
    required this.safety,
  });

  final String attendance;
  final String mainTopic;
  final String outcomes;
  final String nextActions;
  final String impression;
  final String referrals;
  final String safety;

  List<_PersonalLogSection> get sections {
    return [
      _PersonalLogSection('Attendance', attendance),
      _PersonalLogSection('Main topic(s)', mainTopic),
      _PersonalLogSection('Outcome(s)', outcomes),
      _PersonalLogSection('Next action(s)', nextActions),
      _PersonalLogSection('Overall impression', impression),
      _PersonalLogSection('Local referral tracking', referrals),
      _PersonalLogSection('Safety concerns', safety),
    ];
  }

  static List<_PersonalLogSection> fromEntry(WorkEntry entry) {
    final attendance = _attendanceFromEntry(entry);
    final breakdown = entry.supportNoteBreakdown.trim();
    if (breakdown.isEmpty) {
      final notes = entry.notes
          .map((note) => note.trim())
          .where((note) => !note.startsWith('Attendance: '))
          .where((note) => note.isNotEmpty)
          .join('\n');

      return [
        _PersonalLogSection('Attendance', attendance),
        _PersonalLogSection('Main topic(s)', notes),
        const _PersonalLogSection('Outcome(s)', '-'),
        const _PersonalLogSection('Next action(s)', '-'),
        const _PersonalLogSection('Overall impression', '-'),
        const _PersonalLogSection('Local referral tracking', '-'),
        const _PersonalLogSection('Safety concerns', '-'),
      ];
    }

    final breakdownAttendance = _section(breakdown, 'Attendance');
    return _PayeSupportSections(
      attendance: breakdownAttendance.trim().isEmpty
          ? attendance
          : breakdownAttendance,
      mainTopic: _section(breakdown, 'Main topic'),
      outcomes: _section(breakdown, 'Outcome'),
      nextActions: _section(breakdown, 'Next action'),
      impression: _section(breakdown, 'Overall impression'),
      referrals: _section(breakdown, 'Local referral tracking'),
      safety: _section(breakdown, 'Safety concerns'),
    ).sections;
  }

  static String _section(String source, String headingPrefix) {
    final lines = source.split(RegExp(r'\r?\n'));
    final buffer = <String>[];
    var reading = false;

    for (final line in lines) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();
      final isHeading = [
        'attendance',
        'main topic',
        'outcome',
        'next action',
        'overall impression',
        'local referral tracking',
        'safety concerns',
      ].any((heading) => lower.startsWith(heading));

      if (lower.startsWith(headingPrefix.toLowerCase())) {
        reading = true;
        continue;
      }

      if (reading && isHeading) break;
      if (reading && trimmed.isNotEmpty) buffer.add(trimmed);
    }

    return buffer.join('\n');
  }

  static String _attendanceFromEntry(WorkEntry entry) {
    final roles = <String>[];

    for (final note in entry.notes) {
      final trimmed = note.trim();
      if (!trimmed.startsWith('Attendance: ')) continue;

      final value = trimmed.replaceFirst('Attendance: ', '').trim();
      if (value.isEmpty) continue;

      roles.addAll(
        value
            .split(',')
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty),
      );
    }

    final unique = roles.toSet().toList();
    return unique.isEmpty ? '-' : unique.join('\n');
  }
}

class _SupportNoteSections {
  const _SupportNoteSections({
    required this.mainTopic,
    required this.outcomes,
    required this.nextActions,
    required this.overallImpression,
    required this.referrals,
    required this.safetyConcerns,
  });

  final String mainTopic;
  final String outcomes;
  final String nextActions;
  final String overallImpression;
  final String referrals;
  final String safetyConcerns;

  bool get hasSupportChecks =>
      referrals.trim().isNotEmpty || safetyConcerns.trim().isNotEmpty;

  String get outcomesWithActions {
    final supportChecks = _supportChecksText;
    final nextActionBlock = [
      if (nextActions.isNotEmpty) nextActions,
      if (supportChecks.isNotEmpty) supportChecks,
    ].join('\n\n');

    if (nextActionBlock.isEmpty) return outcomes;
    if (outcomes.isEmpty) return 'Next action(s)\n$nextActionBlock';

    return '$outcomes\n\nNext action(s)\n$nextActionBlock';
  }

  String get _supportChecksText {
    return [
      if (referrals.isNotEmpty) ...['Local referral tracking', referrals],
      if (safetyConcerns.isNotEmpty) ...[
        'Safety concerns for sexual harm survivors and mental health',
        safetyConcerns,
      ],
    ].join('\n');
  }

  factory _SupportNoteSections.fromNoteText(String value) {
    final main = <String>[];
    final outcomes = <String>[];
    final nextActions = <String>[];
    final overall = <String>[];
    final referrals = <String>[];
    final safetyConcerns = <String>[];
    var section = _SupportNoteSection.main;

    for (final rawLine in value.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trimRight();
      final normalized = line.trimLeft().toLowerCase();

      if (normalized.startsWith('main topic')) {
        section = _SupportNoteSection.main;
        continue;
      }

      if (normalized.startsWith('outcome')) {
        section = _SupportNoteSection.outcomes;
        continue;
      }

      if (normalized.startsWith('next action') ||
          normalized.startsWith('tracked next action')) {
        section = _SupportNoteSection.nextActions;
        continue;
      }

      if (normalized.startsWith('overall impression')) {
        section = _SupportNoteSection.overall;
        continue;
      }

      if (normalized.startsWith('local referral')) {
        section = _SupportNoteSection.referrals;
        continue;
      }

      if (normalized.startsWith('safety concerns')) {
        section = _SupportNoteSection.safetyConcerns;
        continue;
      }

      switch (section) {
        case _SupportNoteSection.main:
          main.add(line);
          break;
        case _SupportNoteSection.outcomes:
          outcomes.add(line);
          break;
        case _SupportNoteSection.nextActions:
          nextActions.add(line);
          break;
        case _SupportNoteSection.overall:
          overall.add(line);
          break;
        case _SupportNoteSection.referrals:
          referrals.add(line);
          break;
        case _SupportNoteSection.safetyConcerns:
          safetyConcerns.add(line);
          break;
      }
    }

    final cleanMain = _cleanLines(main);
    final cleanOutcomes = _cleanLines(outcomes);
    final cleanNextActions = _cleanLines(nextActions);
    final cleanOverall = _cleanLines(overall);

    return _SupportNoteSections(
      mainTopic: cleanMain,
      outcomes: cleanOutcomes,
      nextActions: cleanNextActions,
      overallImpression: cleanOverall,
      referrals: _cleanLines(referrals),
      safetyConcerns: _cleanLines(safetyConcerns),
    );
  }

  static String _cleanLines(Iterable<String> lines) {
    return lines
        .map((line) => line.trimRight())
        .where((line) {
          final trimmed = line.trim();
          return trimmed.isNotEmpty &&
              !RegExp(r'^(\d+[\.)]?|[-*])\s*$').hasMatch(trimmed);
        })
        .join('\n')
        .trim();
  }
}

enum _SupportNoteSection {
  main,
  outcomes,
  nextActions,
  overall,
  referrals,
  safetyConcerns,
}
