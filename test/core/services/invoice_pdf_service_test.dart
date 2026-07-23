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
    const visibleInvoiceNumber = 33;
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
      const visibleInvoiceNumber = 33;
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

  test('saved legacy invoice numbers move to the invoice 20 base', () async {
    final period = PayPeriodRange(
      start: DateTime(2026, 1, 11),
      end: DateTime(2026, 1, 24),
    );

    SharedPreferences.setMockInitialValues({
      'invoice_pdf_last_number_v1': 13,
      'invoice_pdf_number_20260111_20260124': 12,
    });

    expect(await InvoicePdfService.invoiceNumberForPeriod(period), 22);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('invoice_pdf_last_number_v1'), 23);
    expect(prefs.getInt('invoice_pdf_numbering_base_v2'), 20);
  });
}
