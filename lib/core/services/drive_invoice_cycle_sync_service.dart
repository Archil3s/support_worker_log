import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/google_drive_file.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';
import 'google_drive_service.dart';
import 'invoice_pdf_service.dart';
import 'local_support_note_service.dart';

class DriveInvoiceCycleSyncService {
  DriveInvoiceCycleSyncService({GoogleDriveService? driveService})
    : _driveService = driveService ?? GoogleDriveService();

  final GoogleDriveService _driveService;
  static const String _docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  Future<void> syncInvoiceCycles({
    required String accessToken,
    required String rootFolderId,
    required String clientNotesFolderId,
    required String invoicesFolderId,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    final grouped = _groupEntriesByPeriod(
      entries: entries,
      anchorDate: settings.payPeriodAnchorDate,
    );

    for (final item in grouped) {
      await _syncInvoicePeriod(
        accessToken: accessToken,
        invoicesFolderId: invoicesFolderId,
        item: item,
        settings: settings,
      );
    }

    final threeMonthGroups = _groupEntriesByThreeMonthPeriod(entries);

    for (final item in threeMonthGroups) {
      await _syncThreeMonthSummary(
        accessToken: accessToken,
        invoicesFolderId: invoicesFolderId,
        item: item,
        settings: settings,
      );
    }

    await _syncLivingTextNoteLog(
      accessToken: accessToken,
      clientNotesFolderId: clientNotesFolderId,
      entries: entries,
      settings: settings,
    );
  }

  Future<GoogleDriveFile> createInvoicePeriodTotalFolder({
    required String accessToken,
    required String invoicesFolderId,
    required int invoiceNumber,
    required PayPeriodRange range,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    if (entries.isEmpty) {
      throw StateError('No entries in this invoice period.');
    }

    final sortedEntries = entries.toList();
    _sortEntries(sortedEntries);
    await InvoicePdfService.rememberInvoiceNumberForPeriod(
      range,
      invoiceNumber,
    );
    final totalFolder = await _driveService.findOrCreateFolder(
      accessToken: accessToken,
      parentId: invoicesFolderId,
      name:
          'Invoice $invoiceNumber Total - ${_dateKey(range.start)} to '
          '${_dateKey(range.end)}',
    );
    final pdfBytes = await InvoicePdfService.buildInvoicePdf(
      invoiceNumber: invoiceNumber,
      period: range,
      entries: sortedEntries,
      settings: settings,
    );

    await _driveService.uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: totalFolder.id,
      name: 'Invoice_${invoiceNumber}_${_fileSuffix(range)}.pdf',
      mimeType: 'application/pdf',
      bytes: pdfBytes,
    );

    final noteBytes = await LocalSupportNoteService.buildInvoicePeriodNoteDocx(
      invoiceNumber: invoiceNumber,
      start: range.start,
      end: range.end,
      entryCount: sortedEntries.length,
      hours: totalHours(sortedEntries),
      kilometres: totalKilometres(sortedEntries),
      noteText: _invoiceBreakdownText(
        title: 'Invoice $invoiceNumber total folder breakdown',
        start: range.start,
        end: range.end,
        entries: sortedEntries,
        settings: settings,
      ),
    );

    await _driveService.uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: totalFolder.id,
      name:
          'Invoice_Total_Breakdown_${invoiceNumber}_${_fileSuffix(range)}.docx',
      mimeType: _docxMimeType,
      bytes: noteBytes,
    );

    for (final entry in sortedEntries) {
      final meta = await LocalSupportNoteService.loadMeta(entry.id);
      final initials = meta?.initials.trim().isNotEmpty == true
          ? meta!.initials
          : LocalSupportNoteService.defaultInitialsForEntry(entry);
      final status = meta?.status ?? EntrySupportNoteStatus.incomplete;
      final noteText = meta?.noteText.trim().isNotEmpty == true
          ? meta!.noteText
          : LocalSupportNoteService.defaultNoteTextForEntry(
              entry: entry,
              status: status,
            );
      final supportNoteBytes = await LocalSupportNoteService.buildNoteDocx(
        entry: entry,
        initials: initials,
        status: status,
        noteText: noteText,
      );

      await _driveService.uploadOrUpdateFile(
        accessToken: accessToken,
        parentId: totalFolder.id,
        name: _totalFolderSupportNoteFileName(
          entry: entry,
          initials: initials,
          status: status,
        ),
        mimeType: _docxMimeType,
        bytes: supportNoteBytes,
      );
    }

    return totalFolder;
  }

  Future<void> _syncInvoicePeriod({
    required String accessToken,
    required String invoicesFolderId,
    required _InvoicePeriodEntries item,
    required AppSettings settings,
  }) async {
    final invoiceNumber = item.invoiceNumber;
    await InvoicePdfService.rememberInvoiceNumberForPeriod(
      item.range,
      invoiceNumber,
    );
    final invoiceFolder = await _driveService.findOrCreateFolder(
      accessToken: accessToken,
      parentId: invoicesFolderId,
      name: _cycleFolderName(invoiceNumber: invoiceNumber, range: item.range),
    );
    final pdfBytes = await InvoicePdfService.buildInvoicePdf(
      invoiceNumber: invoiceNumber,
      period: item.range,
      entries: item.entries,
      settings: settings,
    );

    await _driveService.uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: invoiceFolder.id,
      name: 'Invoice_${invoiceNumber}_${_fileSuffix(item.range)}.pdf',
      mimeType: 'application/pdf',
      bytes: pdfBytes,
    );

    final noteBytes = await LocalSupportNoteService.buildInvoicePeriodNoteDocx(
      invoiceNumber: invoiceNumber,
      start: item.range.start,
      end: item.range.end,
      entryCount: item.entries.length,
      hours: totalHours(item.entries),
      kilometres: totalKilometres(item.entries),
      noteText: _invoiceBreakdownText(
        title: 'Invoice $invoiceNumber breakdown',
        start: item.range.start,
        end: item.range.end,
        entries: item.entries,
        settings: settings,
      ),
    );

    await _driveService.uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: invoiceFolder.id,
      name:
          'Invoice_Breakdown_${invoiceNumber}_${_fileSuffix(item.range)}.docx',
      mimeType: _docxMimeType,
      bytes: noteBytes,
    );
  }

  Future<void> _syncThreeMonthSummary({
    required String accessToken,
    required String invoicesFolderId,
    required _ThreeMonthEntries item,
    required AppSettings settings,
  }) async {
    final summaryFolder = await _driveService.findOrCreateFolder(
      accessToken: accessToken,
      parentId: invoicesFolderId,
      name:
          '3 Month Summary - ${_dateKey(item.start)} to ${_dateKey(item.end)}',
    );
    final noteBytes = await LocalSupportNoteService.buildInvoicePeriodNoteDocx(
      invoiceNumber: 0,
      start: item.start,
      end: item.end,
      entryCount: item.entries.length,
      hours: totalHours(item.entries),
      kilometres: totalKilometres(item.entries),
      title: '3 Month Summary',
      noteText: _invoiceBreakdownText(
        title: '3 month invoice summary',
        start: item.start,
        end: item.end,
        entries: item.entries,
        settings: settings,
      ),
    );

    await _driveService.uploadOrUpdateFile(
      accessToken: accessToken,
      parentId: summaryFolder.id,
      name: 'Three_Month_Breakdown_${_rangeSuffix(item.start, item.end)}.docx',
      mimeType: _docxMimeType,
      bytes: noteBytes,
    );
  }

  Future<void> _syncLivingTextNoteLog({
    required String accessToken,
    required String clientNotesFolderId,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    final perClient = <String, List<WorkEntry>>{};

    for (final entry in entries) {
      if (!entry.type.isWrittenContact) continue;

      perClient.putIfAbsent(_clientName(entry), () => <WorkEntry>[]).add(entry);
    }

    final clients = perClient.keys.toList()..sort();

    for (final client in clients) {
      final textEntries = perClient[client]!;
      _sortEntries(textEntries);

      final clientFolder = await _driveService.findOrCreateFolder(
        accessToken: accessToken,
        parentId: clientNotesFolderId,
        name: client,
      );
      final noteBytes =
          await LocalSupportNoteService.buildInvoicePeriodNoteDocx(
            invoiceNumber: 0,
            start: textEntries.first.date,
            end: textEntries.last.date,
            entryCount: textEntries.length,
            hours: totalHours(textEntries),
            kilometres: totalKilometres(textEntries),
            title: client,
            noteText: _livingTextNoteLogText(
              client: client,
              textEntries: textEntries,
              settings: settings,
            ),
          );

      await _driveService.uploadOrUpdateFile(
        accessToken: accessToken,
        parentId: clientFolder.id,
        name: 'Living_Text_Notes_Log.docx',
        mimeType: _docxMimeType,
        bytes: noteBytes,
      );
    }
  }

  List<_InvoicePeriodEntries> _groupEntriesByPeriod({
    required List<WorkEntry> entries,
    required DateTime? anchorDate,
  }) {
    final grouped = <String, _InvoicePeriodEntries>{};

    for (final entry in entries) {
      final range = fortnightForDate(entry.date, anchorDate: anchorDate);
      final key = _dateKey(range.start);

      grouped.putIfAbsent(
        key,
        () => _InvoicePeriodEntries(
          invoiceNumber: 0,
          range: range,
          entries: <WorkEntry>[],
        ),
      );
      grouped[key]!.entries.add(entry);
    }

    final items = grouped.values.toList();

    for (final item in items) {
      _sortEntries(item.entries);
    }

    items.sort((a, b) => a.range.start.compareTo(b.range.start));

    if (items.isEmpty) return items;

    final anchorRange = fortnightForDate(
      anchorDate ?? defaultPayPeriodAnchorDate,
      anchorDate: anchorDate,
    );
    final firstStart = items.first.range.start.isBefore(anchorRange.start)
        ? items.first.range.start
        : anchorRange.start;

    return [
      for (final item in items)
        _InvoicePeriodEntries(
          invoiceNumber:
              InvoicePdfService.firstInvoiceNumber +
              (calendarDaysBetween(firstStart, item.range.start) ~/
                  invoicePeriodDays),
          range: item.range,
          entries: item.entries,
        ),
    ];
  }

  List<_ThreeMonthEntries> _groupEntriesByThreeMonthPeriod(
    List<WorkEntry> entries,
  ) {
    final grouped = <String, _ThreeMonthEntries>{};

    for (final entry in entries) {
      final startMonth = ((entry.date.month - 1) ~/ 3) * 3 + 1;
      final start = DateTime(entry.date.year, startMonth);
      final end = DateTime(entry.date.year, startMonth + 3, 0);
      final key = _dateKey(start);

      grouped.putIfAbsent(
        key,
        () =>
            _ThreeMonthEntries(start: start, end: end, entries: <WorkEntry>[]),
      );
      grouped[key]!.entries.add(entry);
    }

    final items = grouped.values.toList();

    for (final item in items) {
      _sortEntries(item.entries);
    }

    items.sort((a, b) => a.start.compareTo(b.start));

    return items;
  }

  String _invoiceBreakdownText({
    required String title,
    required DateTime start,
    required DateTime end,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final clients = entries.map((entry) => entry.client.trim()).toSet()
      ..removeWhere((client) => client.isEmpty);
    final totalTexts = entries
        .where((entry) => entry.type.isWrittenContact)
        .length;
    final totalEmails = entries.where(_isEmailContact).length;
    final typeCounts = <EntryType, int>{};

    for (final entry in entries) {
      typeCounts.update(entry.type, (count) => count + 1, ifAbsent: () => 1);
    }

    final buffer = StringBuffer()
      ..writeln('Main topic(s)')
      ..writeln('$title for ${formatDate(start)} - ${formatDate(end)}.')
      ..writeln()
      ..writeln('Outcome(s)')
      ..writeln('Total contacts: ${entries.length}')
      ..writeln('People contacted: ${clients.length}')
      ..writeln('Total hours: ${totalHours(entries).toStringAsFixed(2)}')
      ..writeln('Total kms: ${totalKilometres(entries).toStringAsFixed(1)}')
      ..writeln('Total earnings: ${money(totalEarnings(entries, settings))}')
      ..writeln('Total written contacts: $totalTexts')
      ..writeln('Total emails: $totalEmails');

    for (final type in EntryType.values) {
      buffer.writeln(
        'Total ${type.label.toLowerCase()}: ${typeCounts[type] ?? 0}',
      );
    }

    buffer
      ..writeln()
      ..writeln('Who got contacted')
      ..writeln(_clientList(entries))
      ..writeln()
      ..writeln('Visit types per person')
      ..writeln(_visitTypesPerClient(entries))
      ..writeln()
      ..writeln('Texts per person')
      ..writeln(_textsPerClient(entries))
      ..writeln()
      ..writeln('Next action(s)')
      ..writeln('-')
      ..writeln()
      ..writeln('Overall impression')
      ..writeln('Invoice-period contact summary generated from saved visits.');

    return buffer.toString().trim();
  }

  String _clientList(List<WorkEntry> entries) {
    final counts = <String, int>{};

    for (final entry in entries) {
      final client = _clientName(entry);
      counts.update(client, (count) => count + 1, ifAbsent: () => 1);
    }

    final clients = counts.keys.toList()..sort();

    return clients.map((client) => '- $client: ${counts[client]}').join('\n');
  }

  String _visitTypesPerClient(List<WorkEntry> entries) {
    final perClient = <String, Map<String, int>>{};

    for (final entry in entries) {
      final client = _clientName(entry);
      final method = _contactMethod(entry);
      final counts = perClient.putIfAbsent(client, () => <String, int>{});
      counts.update(method, (count) => count + 1, ifAbsent: () => 1);
    }

    final clients = perClient.keys.toList()..sort();

    return clients
        .map((client) {
          final counts = perClient[client]!;
          final labels = counts.keys.toList()..sort();
          final summary = labels
              .map((label) => '$label ${counts[label]}')
              .join(', ');

          return '- $client: $summary';
        })
        .join('\n');
  }

  String _textsPerClient(List<WorkEntry> entries) {
    final textEntries = entries
        .where((entry) => entry.type.isWrittenContact)
        .toList();

    if (textEntries.isEmpty) return '- No written contacts recorded.';

    _sortEntries(textEntries);

    final perClient = <String, List<WorkEntry>>{};

    for (final entry in textEntries) {
      perClient.putIfAbsent(_clientName(entry), () => <WorkEntry>[]).add(entry);
    }

    final clients = perClient.keys.toList()..sort();
    final buffer = StringBuffer();

    for (final client in clients) {
      final items = perClient[client]!;
      buffer.writeln('- $client: ${items.length} text(s)');

      for (final entry in items) {
        final importance = entry.importantText ? 'Important' : 'Not important';
        buffer.writeln(
          '  - ${formatDate(entry.date)} ${formatTime(entry.startTime)} '
          '(${entry.textContactDirection.label}, $importance, '
          '${entry.textReplyNeeded ? 'reply needed' : 'no reply needed'}): '
          '${_textSummary(entry)}',
        );
      }
    }

    return buffer.toString().trim();
  }

  String _livingTextNoteLogText({
    required String client,
    required List<WorkEntry> textEntries,
    required AppSettings settings,
  }) {
    final totalTextHours = totalHours(textEntries);
    final totalTextEarnings = totalEarnings(textEntries, settings);
    final importantCount = textEntries
        .where((entry) => entry.importantText)
        .length;
    final replyNeededCount = textEntries
        .where((entry) => entry.textReplyNeeded)
        .length;
    final openActions = textEntries
        .expand((entry) => entry.nextActions)
        .where((action) => !action.isCompleted)
        .length;
    final firstDate = textEntries.first.date;
    final lastDate = textEntries.last.date;
    final buffer = StringBuffer()
      ..writeln('Main topic(s)')
      ..writeln(
        '$client Living Text Notes Log for ${formatDate(firstDate)} - ${formatDate(lastDate)}.',
      )
      ..writeln()
      ..writeln('Outcome(s)')
      ..writeln('Text note summary')
      ..writeln('- Text notes: ${textEntries.length}')
      ..writeln('- Important: $importantCount')
      ..writeln('- Not important: ${textEntries.length - importantCount}')
      ..writeln('- Reply needed: $replyNeededCount')
      ..writeln('- No reply needed: ${textEntries.length - replyNeededCount}')
      ..writeln('- Billable text hours: ${totalTextHours.toStringAsFixed(2)}')
      ..writeln('- Billable text earnings: ${money(totalTextEarnings)}')
      ..writeln('- Open text actions: $openActions')
      ..writeln()
      ..writeln('Text note timeline');

    for (final entry in textEntries) {
      final importance = entry.importantText ? 'Important' : 'Not important';
      buffer
        ..writeln()
        ..writeln(
          '${formatDate(entry.date)} ${formatTime(entry.startTime)} - ${_clientName(entry)}',
        )
        ..writeln('- Date: ${formatDate(entry.date)}')
        ..writeln('- Time: ${formatTime(entry.startTime)}')
        ..writeln('- Direction: ${_textDirectionLabel(entry)}')
        ..writeln('- Important: $importance')
        ..writeln('- Reply needed: ${entry.textReplyNeeded ? 'Yes' : 'No'}')
        ..writeln('- Billable minutes: ${entry.baseMinutes}')
        ..writeln('- Billable hours: ${entry.hours.toStringAsFixed(2)}')
        ..writeln('- Summary: ${_textSummary(entry)}');

      final actions = entry.nextActions.where((action) => !action.isCompleted);
      if (actions.isNotEmpty) {
        buffer.writeln('- Next actions:');
        for (final action in actions) {
          buffer.writeln('  - ${action.text}');
        }
      }
    }

    final allOpenActions = textEntries
        .expand((entry) => entry.nextActions)
        .where((action) => !action.isCompleted)
        .toList();

    buffer
      ..writeln()
      ..writeln('Next action(s)');

    if (allOpenActions.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final action in allOpenActions) {
        buffer.writeln('- ${action.text}');
      }
    }

    buffer
      ..writeln()
      ..writeln('Overall impression')
      ..writeln(
        'Single living Google Drive document generated from saved billable text notes.',
      );

    return buffer.toString().trim();
  }

  String _textDirectionLabel(WorkEntry entry) {
    return 'Text ${entry.textContactDirection.label.toLowerCase()}';
  }

  String _textSummary(WorkEntry entry) {
    final text = entry.supportNoteBreakdown.trim();

    if (text.isEmpty) {
      final notes = entry.notes
          .map((note) => note.trim())
          .where((note) => note.isNotEmpty);

      return notes.isEmpty ? 'No written summary recorded.' : notes.join('; ');
    }

    final lines = text.split(RegExp(r'\r?\n'));
    final summary = <String>[];
    var readingSummary = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final normalized = line.toLowerCase();

      if (normalized.startsWith('text contact summary') ||
          normalized.startsWith('contact summary')) {
        readingSummary = true;
        continue;
      }

      if (readingSummary &&
          (normalized.startsWith('reply needed') ||
              normalized.startsWith('next action'))) {
        break;
      }

      if (readingSummary && line.isNotEmpty) {
        summary.add(line);
      }
    }

    if (summary.isNotEmpty) return summary.join(' ');

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _contactMethod(WorkEntry entry) {
    if (_isEmailContact(entry)) return 'Email';
    return entry.type.label;
  }

  bool _isEmailContact(WorkEntry entry) {
    final text = [
      entry.type.label,
      ...entry.notes,
      entry.supportNoteBreakdown,
    ].join(' ').toLowerCase();

    return text.contains('email') || text.contains('e-mail');
  }

  String _clientName(WorkEntry entry) {
    final client = entry.client.trim();
    return client.isEmpty ? 'Unknown Client' : client;
  }

  void _sortEntries(List<WorkEntry> entries) {
    entries.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
      final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  String _cycleFolderName({
    required int invoiceNumber,
    required PayPeriodRange range,
  }) {
    return 'Invoice $invoiceNumber - ${_dateKey(range.start)} to ${_dateKey(range.end)}';
  }

  String _totalFolderSupportNoteFileName({
    required WorkEntry entry,
    required String initials,
    required EntrySupportNoteStatus status,
  }) {
    final fileName = [
      _dateKey(entry.date),
      _safeFilePart(_clientName(entry)),
      _safeFilePart(entry.type.label),
      _safeFilePart(initials).toUpperCase(),
      status.fileSlug,
    ].where((part) => part.isNotEmpty).join('_');

    return '$fileName.docx';
  }

  String _safeFilePart(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  String _fileSuffix(PayPeriodRange range) {
    return '${_dateKey(range.start)}_${_dateKey(range.end)}';
  }

  String _rangeSuffix(DateTime start, DateTime end) {
    return '${_dateKey(start)}_${_dateKey(end)}';
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

class _InvoicePeriodEntries {
  _InvoicePeriodEntries({
    required this.invoiceNumber,
    required this.range,
    required this.entries,
  });

  final int invoiceNumber;
  final PayPeriodRange range;
  final List<WorkEntry> entries;
}

class _ThreeMonthEntries {
  _ThreeMonthEntries({
    required this.start,
    required this.end,
    required this.entries,
  });

  final DateTime start;
  final DateTime end;
  final List<WorkEntry> entries;
}
