import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';

class PdfTimesheetService {
  const PdfTimesheetService();

  Future<Uint8List> buildTimesheetPdf({
    required List<WorkEntry> entries,
    required AppSettings settings,
    required PayPeriodRange range,
    required PdfPageFormat pageFormat,
  }) async {
    final document = pw.Document();

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

    final gross = totalEarnings(periodEntries, settings);
    final acc = gross * settings.accRate;
    final kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final gst = gross * settings.gstRate;
    final net = gross - acc - kiwiSaver - gst;

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Text(
              'Support Worker Timesheet',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${formatDate(range.start)} - ${formatDate(range.end)}',
              style: const pw.TextStyle(fontSize: 13),
            ),
            pw.Text(
              'Generated: ${formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 18),
            _sectionTitle('Period Totals'),
            _keyValueTable([
              ['Entries', '${periodEntries.length}'],
              ['Hours', totalHours(periodEntries).toStringAsFixed(2)],
              ['Earnings', money(gross)],
              ['Kilometres', totalKilometres(periodEntries).toStringAsFixed(1)],
              [
                'Fuel reimbursement',
                money(_totalFuel(periodEntries, settings)),
              ],
            ]),
            pw.SizedBox(height: 14),
            _sectionTitle('Week 1'),
            _keyValueTable([
              [
                'Date range',
                '${formatDate(range.weekOneStart)} - ${formatDate(range.weekOneEnd)}',
              ],
              ['Entries', '${weekOneEntries.length}'],
              ['Hours', totalHours(weekOneEntries).toStringAsFixed(2)],
              ['Earnings', money(totalEarnings(weekOneEntries, settings))],
              [
                'Kilometres',
                totalKilometres(weekOneEntries).toStringAsFixed(1),
              ],
            ]),
            pw.SizedBox(height: 12),
            _sectionTitle('Week 2'),
            _keyValueTable([
              [
                'Date range',
                '${formatDate(range.weekTwoStart)} - ${formatDate(range.weekTwoEnd)}',
              ],
              ['Entries', '${weekTwoEntries.length}'],
              ['Hours', totalHours(weekTwoEntries).toStringAsFixed(2)],
              ['Earnings', money(totalEarnings(weekTwoEntries, settings))],
              [
                'Kilometres',
                totalKilometres(weekTwoEntries).toStringAsFixed(1),
              ],
            ]),
            pw.SizedBox(height: 14),
            _sectionTitle('Tax Estimate'),
            _keyValueTable([
              ['Gross income', money(gross)],
              [
                'ACC levy',
                '-${money(acc)} (${(settings.accRate * 100).toStringAsFixed(2)}%)',
              ],
              [
                'KiwiSaver',
                settings.kiwiSaverEnabled
                    ? '-${money(kiwiSaver)} (${(settings.kiwiSaverRate * 100).toStringAsFixed(1)}%)'
                    : 'Off',
              ],
              [
                'GST estimate',
                '-${money(gst)} (${(settings.gstRate * 100).toStringAsFixed(1)}%)',
              ],
              ['Net take-home estimate', money(net)],
            ]),
            pw.SizedBox(height: 14),
            _sectionTitle('Entries'),
            if (periodEntries.isEmpty)
              pw.Text('No entries in this pay period.')
            else
              _entriesTable(periodEntries, settings),
            pw.SizedBox(height: 16),
            pw.Text(
              'Tax figures are planning estimates only. Confirm final tax, GST, ACC, and KiwiSaver obligations with official sources or an accountant.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.4),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [_tableCell(row[0], bold: true), _tableCell(row[1])],
          ),
      ],
    );
  }

  pw.Widget _entriesTable(List<WorkEntry> entries, AppSettings settings) {
    final rows = <List<String>>[
      ['Date', 'Start', 'Client', 'Type', 'Min', 'Earn', 'KM', 'Notes'],
      for (final entry in entries)
        [
          formatDate(entry.date),
          formatTime(entry.startTime),
          entry.client,
          entry.type.label,
          entry.minutes.toString(),
          money(entry.earnings(settings)),
          entry.type == EntryType.homeVisit
              ? entry.kilometres.toStringAsFixed(1)
              : '',
          entry.notes.join('; '),
        ],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(0.5),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(0.5),
        7: pw.FlexColumnWidth(1.8),
      },
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
          pw.TableRow(
            decoration: rowIndex == 0
                ? const pw.BoxDecoration(color: PdfColors.grey300)
                : null,
            children: [
              for (final cell in rows[rowIndex])
                _tableCell(cell, bold: rowIndex == 0, fontSize: 8),
            ],
          ),
      ],
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool bold = false,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  double _totalFuel(List<WorkEntry> entries, AppSettings settings) {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.fuelReimbursement(settings),
    );
  }
}
