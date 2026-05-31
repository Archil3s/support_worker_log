import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry_type.dart';
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
        entry: entry,
        initials: initials,
        status: status,
        noteText: noteText,
      );
    } catch (error) {
      throw StateError(
        'Gold-standard support note template could not be loaded: $error',
      );
    }
  }

  static List<int> _docxFromTemplate({
    required Uint8List bytes,
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
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
            entry: entry,
            initials: initials,
            status: status,
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
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
    required String noteText,
  }) {
    final sections = _SupportNoteSections.fromNoteText(
      noteText.trim().isEmpty
          ? defaultNoteTextForEntry(entry: entry, status: status)
          : noteText,
    );
    final clientInitials = initials.trim().toUpperCase();
    final interactionText =
        '${formatDate(entry.date)} / ${formatTime(entry.startTime)} / '
        '${entry.baseMinutes} minutes '
        '(${entry.hours.toStringAsFixed(2)} hours). '
        '${entry.type.label}.${_kilometresText(entry)}';

    final paragraphPattern = RegExp(r'<w:p[\s\S]*?<\/w:p>');
    final buffer = StringBuffer();
    var cursor = 0;
    var pendingBlankFill = '';

    for (final match in paragraphPattern.allMatches(xml)) {
      buffer.write(xml.substring(cursor, match.start));
      var paragraph = match.group(0)!;
      final text = _paragraphText(paragraph).trim();

      if (text.startsWith('Name of client.')) {
        paragraph = _appendTextToParagraph(paragraph, clientInitials);
      } else if (text == 'Date:') {
        paragraph = _appendTextToParagraph(
          paragraph,
          ' ${formatDate(entry.date)}',
        );
      } else if (text.startsWith('Date/time/length of interaction.')) {
        pendingBlankFill = interactionText;
      } else if (text.startsWith('Main topic')) {
        pendingBlankFill = sections.mainTopic;
      } else if (text.startsWith('Outcome')) {
        pendingBlankFill = sections.outcomesWithActions;
      } else if (text.startsWith('Overall impression')) {
        pendingBlankFill = sections.overallImpression;
      } else if (pendingBlankFill.isNotEmpty && text.isEmpty) {
        paragraph = _fillBlankParagraph(paragraph, pendingBlankFill);
        pendingBlankFill = '';
      }

      buffer.write(paragraph);
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

  static String _appendTextToParagraph(String paragraphXml, String text) {
    return paragraphXml.replaceFirst(
      '</w:p>',
      '${_runXml(text, bold: true)}</w:p>',
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

class _SupportNoteSections {
  const _SupportNoteSections({
    required this.mainTopic,
    required this.outcomes,
    required this.nextActions,
    required this.overallImpression,
  });

  final String mainTopic;
  final String outcomes;
  final String nextActions;
  final String overallImpression;

  String get outcomesWithActions {
    if (nextActions.isEmpty) return outcomes;
    if (outcomes.isEmpty) return 'Next action(s)\n$nextActions';

    return '$outcomes\n\nNext action(s)\n$nextActions';
  }

  factory _SupportNoteSections.fromNoteText(String value) {
    final main = <String>[];
    final outcomes = <String>[];
    final nextActions = <String>[];
    final overall = <String>[];
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

enum _SupportNoteSection { main, outcomes, nextActions, overall }
