import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/services/invoice_pdf_service.dart';
import 'package:support_worker_log/core/utils/pay_period_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('anchor-based invoice number ignores stale period number', () {
    const staleNumber = 13;
    const visibleInvoiceNumber = 18;
    final period = PayPeriodRange(
      start: DateTime(2026, 5, 30),
      end: DateTime(2026, 6, 12),
    );

    SharedPreferences.setMockInitialValues({
      'invoice_pdf_last_number_v1': staleNumber,
      'invoice_pdf_number_20260530_20260612': staleNumber,
    });

    expect(
      InvoicePdfService.invoiceNumberForPeriodAnchor(
        period,
        anchorDate: DateTime(2025, 11, 29),
      ),
      visibleInvoiceNumber,
    );
  });

  test(
    'rememberInvoiceNumberForPeriod overwrites stale period number',
    () async {
      const staleNumber = 13;
      const visibleInvoiceNumber = 18;
      final period = PayPeriodRange(
        start: DateTime(2026, 5, 30),
        end: DateTime(2026, 6, 12),
      );

      SharedPreferences.setMockInitialValues({
        'invoice_pdf_last_number_v1': staleNumber,
        'invoice_pdf_number_20260530_20260612': staleNumber,
      });

      expect(
        await InvoicePdfService.rememberInvoiceNumberForPeriod(
          period,
          visibleInvoiceNumber,
        ),
        visibleInvoiceNumber,
      );
    },
  );

  test(
    'saved legacy invoice numbers move to the current invoice base',
    () async {
      final period = PayPeriodRange(
        start: DateTime(2026, 1, 11),
        end: DateTime(2026, 1, 24),
      );

      SharedPreferences.setMockInitialValues({
        'invoice_pdf_last_number_v1': 13,
        'invoice_pdf_number_20260111_20260124': 12,
      });

      expect(await InvoicePdfService.invoiceNumberForPeriod(period), 7);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('invoice_pdf_last_number_v1'), 8);
      expect(prefs.getInt('invoice_pdf_numbering_base_v2'), 5);
    },
  );

  test(
    'invoice 20 rollout numbers migrate back to invoices 18 and 19',
    () async {
      final paidPeriod = PayPeriodRange(
        start: DateTime(2026, 6, 14),
        end: DateTime(2026, 6, 27),
      );

      SharedPreferences.setMockInitialValues({
        'invoice_pdf_numbering_base_v2': 20,
        'invoice_pdf_last_number_v1': 34,
        'invoice_pdf_number_20260614_20260627': 33,
      });

      expect(await InvoicePdfService.invoiceNumberForPeriod(paidPeriod), 18);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('invoice_pdf_last_number_v1'), 19);
      expect(prefs.getInt('invoice_pdf_numbering_base_v2'), 5);
    },
  );

  test('paid and unpaid periods are numbered 18 through 21', () {
    final expectedNumbers = <DateTime, int>{
      DateTime(2026, 5, 30): 18,
      DateTime(2026, 6, 13): 19,
      DateTime(2026, 6, 27): 20,
      DateTime(2026, 7, 11): 21,
    };

    for (final item in expectedNumbers.entries) {
      expect(
        InvoicePdfService.invoiceNumberForPeriodAnchor(
          PayPeriodRange(
            start: item.key,
            end: addCalendarDays(item.key, invoicePeriodDays - 1),
          ),
          anchorDate: DateTime(2025, 11, 29),
        ),
        item.value,
      );
    }
  });
}
