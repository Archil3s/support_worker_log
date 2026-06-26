import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/work_entry.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';

class InvoicePdfService {
  const InvoicePdfService._();

  static const int firstInvoiceNumber = 10;
  static const String _lastInvoiceNumberKey = 'invoice_pdf_last_number_v1';

  static Future<void> exportInvoice({
    required int invoiceNumber,
    required PayPeriodRange period,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    await rememberInvoiceNumberForPeriod(period, invoiceNumber);

    final bytes = await buildInvoicePdf(
      invoiceNumber: invoiceNumber,
      period: period,
      entries: entries,
      settings: settings,
    );

    final fileName = 'Invoice $invoiceNumber.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<int> invoiceNumberForPeriod(
    PayPeriodRange period, {
    DateTime? anchorDate,
  }) async {
    if (anchorDate != null) {
      return rememberInvoiceNumberForPeriod(
        period,
        invoiceNumberForPeriodAnchor(period, anchorDate: anchorDate),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final periodKey = _periodInvoiceNumberKey(period);

    final existing = prefs.getInt(periodKey);
    if (existing != null) {
      return existing;
    }

    final lastNumber = prefs.getInt(_lastInvoiceNumberKey);
    final nextNumber = lastNumber == null ? firstInvoiceNumber : lastNumber + 1;

    await prefs.setInt(periodKey, nextNumber);
    await prefs.setInt(_lastInvoiceNumberKey, nextNumber);

    return nextNumber;
  }

  static int invoiceNumberForPeriodAnchor(
    PayPeriodRange period, {
    DateTime? anchorDate,
  }) {
    final anchorRange = fortnightForDate(
      anchorDate ?? defaultPayPeriodAnchorDate,
      anchorDate: anchorDate,
    );
    final periodOffset =
        calendarDaysBetween(anchorRange.start, period.start) ~/
        invoicePeriodDays;

    return firstInvoiceNumber + periodOffset;
  }

  static Future<int> rememberInvoiceNumberForPeriod(
    PayPeriodRange period,
    int invoiceNumber,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final periodKey = _periodInvoiceNumberKey(period);
    final lastNumber = prefs.getInt(_lastInvoiceNumberKey);

    await prefs.setInt(periodKey, invoiceNumber);

    if (lastNumber == null || invoiceNumber > lastNumber) {
      await prefs.setInt(_lastInvoiceNumberKey, invoiceNumber);
    }

    return invoiceNumber;
  }

  static String _periodInvoiceNumberKey(PayPeriodRange period) {
    return 'invoice_pdf_number_${_fileDate(period.start)}_${_fileDate(period.end)}';
  }

  static Future<Uint8List> buildInvoicePdf({
    required int invoiceNumber,
    required PayPeriodRange period,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    final pdf = pw.Document();

    final hours = totalHours(entries);
    final kms = totalKilometres(entries);

    final hoursRate = settings.hourlyRate;
    final kmsRate = settings.fuelRate;

    final hoursAmount = totalEarnings(entries, settings);
    final kmsAmount = kms * kmsRate;
    final totalAmount = hoursAmount + kmsAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 34),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(invoiceNumber: invoiceNumber, period: period),
              pw.SizedBox(height: 14),
              _toForBlock(),
              pw.SizedBox(height: 16),
              _invoiceTable(
                hours: hours,
                kms: kms,
                hoursRate: hoursRate,
                kmsRate: kmsRate,
                hoursAmount: hoursAmount,
                kmsAmount: kmsAmount,
                totalAmount: totalAmount,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header({
    required int invoiceNumber,
    required PayPeriodRange period,
  }) {
    return pw.Container(
      height: 92,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.7),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.grey500, width: 0.7),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Male Room',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '[Fax Number]',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'J D DuToit',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '06-0603-0098537-00',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.topRight,
                    padding: const pw.EdgeInsets.only(top: 7, right: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey500,
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ),
                pw.Container(
                  height: 46,
                  alignment: pw.Alignment.bottomRight,
                  padding: const pw.EdgeInsets.only(right: 8, bottom: 6),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE $invoiceNumber',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'DATE: ${_formatDate(period.start)} - ${_formatDate(period.end)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _toForBlock() {
    return pw.Container(
      height: 82,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.7),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.grey500, width: 0.7),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TO:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Male Room 2021 Trust',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FOR:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Peer Support services',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _invoiceTable({
    required double hours,
    required double kms,
    required double hoursRate,
    required double kmsRate,
    required double hoursAmount,
    required double kmsAmount,
    required double totalAmount,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(4.0),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.0),
      },
      children: [
        _row(
          ['DESCRIPTION', 'HOURS', 'RATE', 'AMOUNT'],
          bold: true,
          center: true,
          height: 18,
        ),
        _row([
          'Peer support hours',
          hours.toStringAsFixed(2),
          _money(hoursRate),
          _money(hoursAmount),
        ]),
        _row([
          'Travel kms',
          kms.toStringAsFixed(1),
          _money(kmsRate),
          _money(kmsAmount),
        ]),
        for (var i = 0; i < 14; i++) _row(['', '', '', '']),
        _row(['', '', 'TOTAL', _money(totalAmount)], bold: true),
      ],
    );
  }

  static pw.TableRow _row(
    List<String> cells, {
    bool bold = false,
    bool center = false,
    double height = 20,
  }) {
    return pw.TableRow(
      children: [
        for (final cell in cells)
          pw.Container(
            height: height,
            alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: pw.Text(
              cell,
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }

  static String _fileDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}$month$day';
  }

  static String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}
