import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';

class ExcelWorkbookResult {
  const ExcelWorkbookResult({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class ExcelExportService {
  const ExcelExportService();

  ExcelWorkbookResult buildPayPeriodWorkbook({
    required List<WorkEntry> entries,
    required AppSettings settings,
    required PayPeriodRange range,
  }) {
    final excel = Excel.createExcel();

    final summarySheet = excel['Summary'];
    final entriesSheet = excel['Entries'];
    final taxSheet = excel['Tax Estimate'];

    final periodEntries = entriesInRange(entries, range);
    final weekOneEntries = entriesBetween(
      entries,
      range.weekOneStart,
      range.weekOneEnd,
    );
    final weekTwoEntries = entriesBetween(
      entries,
      range.weekTwoStart,
      range.weekTwoEnd,
    );

    _buildSummarySheet(
      sheet: summarySheet,
      range: range,
      periodEntries: periodEntries,
      weekOneEntries: weekOneEntries,
      weekTwoEntries: weekTwoEntries,
      settings: settings,
    );

    _buildEntriesSheet(
      sheet: entriesSheet,
      entries: periodEntries,
      settings: settings,
    );

    _buildTaxSheet(sheet: taxSheet, entries: periodEntries, settings: settings);

    excel.setDefaultSheet('Summary');

    final defaultSheet = excel.sheets.keys.contains('Sheet1');
    if (defaultSheet) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode() ?? <int>[];
    final fileName =
        'support_worker_log_${_fileDate(range.start)}_${_fileDate(range.end)}';

    return ExcelWorkbookResult(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  void _buildSummarySheet({
    required Sheet sheet,
    required PayPeriodRange range,
    required List<WorkEntry> periodEntries,
    required List<WorkEntry> weekOneEntries,
    required List<WorkEntry> weekTwoEntries,
    required AppSettings settings,
  }) {
    _appendTitle(sheet, 'Support Worker Log - Pay Period Summary');
    _appendSpacer(sheet);

    _appendRow(sheet, ['Period Start', formatDate(range.start)]);
    _appendRow(sheet, ['Period End', formatDate(range.end)]);
    _appendRow(sheet, ['Generated', formatDate(DateTime.now())]);
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Period Totals', 'Value']);
    _appendRow(sheet, ['Entries', periodEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(periodEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(periodEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(periodEntries)]);
    _appendRow(sheet, [
      'Fuel Reimbursement',
      _totalFuel(periodEntries, settings),
    ]);
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Week 1',
      '${formatDate(range.weekOneStart)} - ${formatDate(range.weekOneEnd)}',
    ]);
    _appendRow(sheet, ['Entries', weekOneEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(weekOneEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(weekOneEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(weekOneEntries)]);
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Week 2',
      '${formatDate(range.weekTwoStart)} - ${formatDate(range.weekTwoEnd)}',
    ]);
    _appendRow(sheet, ['Entries', weekTwoEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(weekTwoEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(weekTwoEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(weekTwoEntries)]);
  }

  void _buildEntriesSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    _appendTitle(sheet, 'Selected Fortnight Entries');
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Date',
      'Start Time',
      'Client',
      'Entry Type',
      'Minutes',
      'Hours',
      'Earnings',
      'Odometer Start',
      'Odometer Finish',
      'Kilometres',
      'Fuel Reimbursement',
      'Notes',
    ]);

    for (final entry in entries) {
      _appendRow(sheet, [
        formatDate(entry.date),
        formatTime(entry.startTime),
        entry.client,
        entry.type.label,
        entry.minutes,
        entry.hours,
        entry.earnings(settings),
        entry.odometerStart ?? '',
        entry.odometerEnd ?? '',
        entry.kilometres,
        entry.fuelReimbursement(settings),
        entry.notes.join('; '),
      ]);
    }
  }

  void _buildTaxSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final gross = totalEarnings(entries, settings);
    final acc = gross * settings.accRate;
    final kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final gst = gross * settings.gstRate;
    final net = gross - acc - kiwiSaver - gst;

    _appendTitle(sheet, 'Tax Estimate');
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Item', 'Amount', 'Rate']);
    _appendRow(sheet, ['Gross Income', gross, '']);
    _appendRow(sheet, ['ACC Levy', -acc, settings.accRate]);
    _appendRow(sheet, [
      'KiwiSaver',
      -kiwiSaver,
      settings.kiwiSaverEnabled ? settings.kiwiSaverRate : 'Off',
    ]);
    _appendRow(sheet, ['GST Estimate', -gst, settings.gstRate]);
    _appendRow(sheet, ['Net Take-home Estimate', net, '']);
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Period Inputs', 'Value']);
    _appendRow(sheet, ['Entries', entries.length]);
    _appendRow(sheet, ['Hours', totalHours(entries)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(entries)]);
    _appendRow(sheet, ['Hourly Rate', settings.hourlyRate]);
    _appendRow(sheet, ['Fuel Rate / KM', settings.fuelRate]);
  }

  void _appendTitle(Sheet sheet, String title) {
    sheet.appendRow([TextCellValue(title)]);
  }

  void _appendHeader(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cellValue).toList());
  }

  void _appendRow(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cellValue).toList());
  }

  void _appendSpacer(Sheet sheet) {
    sheet.appendRow([TextCellValue('')]);
  }

  CellValue _cellValue(Object? value) {
    if (value == null) {
      return TextCellValue('');
    }

    if (value is int) {
      return IntCellValue(value);
    }

    if (value is double) {
      return DoubleCellValue(value);
    }

    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }

    if (value is bool) {
      return BoolCellValue(value);
    }

    return TextCellValue(value.toString());
  }

  double _totalFuel(List<WorkEntry> entries, AppSettings settings) {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.fuelReimbursement(settings),
    );
  }

  String _fileDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
