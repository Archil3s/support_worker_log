import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/work_entry.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';
import 'local_support_notes/local_support_notes_platform.dart';

enum InvoicePeriodNoteStatus { incomplete, inProgress, finished, submitted }

extension InvoicePeriodNoteStatusLabel on InvoicePeriodNoteStatus {
  String get label {
    switch (this) {
      case InvoicePeriodNoteStatus.incomplete:
        return 'Incomplete';
      case InvoicePeriodNoteStatus.inProgress:
        return 'In Progress';
      case InvoicePeriodNoteStatus.finished:
        return 'Finished';
      case InvoicePeriodNoteStatus.submitted:
        return 'Submitted';
    }
  }

  String get fileSlug {
    switch (this) {
      case InvoicePeriodNoteStatus.incomplete:
        return 'incomplete';
      case InvoicePeriodNoteStatus.inProgress:
        return 'in-progress';
      case InvoicePeriodNoteStatus.finished:
        return 'finished';
      case InvoicePeriodNoteStatus.submitted:
        return 'submitted';
    }
  }
}

class InvoicePeriodNoteMeta {
  const InvoicePeriodNoteMeta({
    required this.periodKey,
    required this.initials,
    required this.status,
    required this.fileName,
    required this.noteText,
  });

  final String periodKey;
  final String initials;
  final InvoicePeriodNoteStatus status;
  final String fileName;
  final String noteText;

  Map<String, dynamic> toJson() {
    return {
      'periodKey': periodKey,
      'initials': initials,
      'status': status.name,
      'fileName': fileName,
      'noteText': noteText,
    };
  }

  factory InvoicePeriodNoteMeta.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;

    final status = InvoicePeriodNoteStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => InvoicePeriodNoteStatus.incomplete,
    );

    return InvoicePeriodNoteMeta(
      periodKey: json['periodKey'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      status: status,
      fileName: json['fileName'] as String? ?? '',
      noteText: json['noteText'] as String? ?? '',
    );
  }
}

class InvoicePeriodNoteService {
  InvoicePeriodNoteService._();

  static final LocalSupportNotesPlatform _platform =
      LocalSupportNotesPlatform();

  static Future<bool> chooseFolder() {
    return _platform.chooseFolder();
  }

  static String periodKey(PayPeriodRange range) {
    return '${_fileDate(range.start)}_${_fileDate(range.end)}';
  }

  static String _metaKey(PayPeriodRange range) {
    return 'invoice_period_local_note_${periodKey(range)}';
  }

  static Future<InvoicePeriodNoteMeta?> loadMeta(PayPeriodRange range) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey(range));

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return InvoicePeriodNoteMeta.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<InvoicePeriodNoteMeta> saveNote({
    required int invoiceNumber,
    required PayPeriodRange range,
    required List<WorkEntry> entries,
    required AppSettings settings,
    required String initials,
    required InvoicePeriodNoteStatus status,
    required String noteText,
  }) async {
    final cleanedInitials = initials.trim().toUpperCase();

    if (cleanedInitials.isEmpty) {
      throw StateError('Enter initials first.');
    }

    final existing = await loadMeta(range);

    final fileName = _fileName(
      invoiceNumber: invoiceNumber,
      range: range,
      initials: cleanedInitials,
      status: status,
    );

    final contents = _template(
      invoiceNumber: invoiceNumber,
      range: range,
      entries: entries,
      settings: settings,
      initials: cleanedInitials,
      status: status,
      noteText: noteText,
      fileName: fileName,
    );

    if (existing != null &&
        existing.fileName.isNotEmpty &&
        existing.fileName != fileName) {
      await _platform.renameFile(
        oldFileName: existing.fileName,
        newFileName: fileName,
        contents: contents,
      );
    } else {
      await _platform.writeFile(fileName: fileName, contents: contents);
    }

    final meta = InvoicePeriodNoteMeta(
      periodKey: periodKey(range),
      initials: cleanedInitials,
      status: status,
      fileName: fileName,
      noteText: noteText,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaKey(range), jsonEncode(meta.toJson()));

    return meta;
  }

  static Future<InvoicePeriodNoteMeta> saveDraftMeta({
    required int invoiceNumber,
    required PayPeriodRange range,
    required String initials,
    required InvoicePeriodNoteStatus status,
    required String noteText,
  }) async {
    final cleanedInitials = initials.trim().toUpperCase().isEmpty
        ? 'NA'
        : initials.trim().toUpperCase();
    final meta = InvoicePeriodNoteMeta(
      periodKey: periodKey(range),
      initials: cleanedInitials,
      status: status,
      fileName: _fileName(
        invoiceNumber: invoiceNumber,
        range: range,
        initials: cleanedInitials,
        status: status,
      ),
      noteText: noteText,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaKey(range), jsonEncode(meta.toJson()));

    return meta;
  }

  static Future<bool> openNote(InvoicePeriodNoteMeta meta) {
    return _platform.openFile(meta.fileName);
  }

  static String _fileName({
    required int invoiceNumber,
    required PayPeriodRange range,
    required String initials,
    required InvoicePeriodNoteStatus status,
  }) {
    return 'Invoice_${invoiceNumber}_${_fileDate(range.start)}_${_fileDate(range.end)}_${initials}_${status.fileSlug}.txt';
  }

  static String _template({
    required int invoiceNumber,
    required PayPeriodRange range,
    required List<WorkEntry> entries,
    required AppSettings settings,
    required String initials,
    required InvoicePeriodNoteStatus status,
    required String noteText,
    required String fileName,
  }) {
    final hours = totalHours(entries).toStringAsFixed(2);
    final kms = totalKilometres(entries).toStringAsFixed(1);
    final earnings = totalEarnings(entries, settings).toStringAsFixed(2);

    final entryLines = entries.isEmpty
        ? '- No entries in this 2-week period'
        : entries
              .map(
                (entry) =>
                    '- ${_displayDate(entry.date)} | ${entry.client} | ${entry.hours.toStringAsFixed(2)} hrs | ${entry.kilometres.toStringAsFixed(1)} km',
              )
              .join('\n');

    return '''
2-WEEK INVOICE PERIOD NOTE
==========================

LOCAL FILE
$fileName

INVOICE
Invoice $invoiceNumber

STATUS
${status.label}

INITIALS
$initials

INVOICE PERIOD
${_displayDate(range.start)} - ${_displayDate(range.end)}

TOTALS
Entries: ${entries.length}
Hours: $hours
KM: $kms
Earnings: \$$earnings

PERIOD ENTRIES
$entryLines

SUPPORT WORKER NOTE
${noteText.trim().isEmpty ? '-' : noteText.trim()}

FOLLOW-UP / ACTIONS
-

LOCAL ONLY
This file is saved to the selected local folder only.
It is not saved to Firebase, any server, database, or cloud by this feature.
''';
  }

  static String _fileDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String _displayDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }
}
