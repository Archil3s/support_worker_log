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
    const visibleInvoiceNumber = 23;
    final period = PayPeriodRange(
      start: DateTime(2026, 5, 30),
      end: DateTime(2026, 6, 12),
    );

    SharedPreferences.setMockInitialValues({
      'invoice_pdf_last_number_v1': staleNumber,
      'invoice_pdf_number_2026-05-30_2026-06-12': staleNumber,
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
      const visibleInvoiceNumber = 23;
      final period = PayPeriodRange(
        start: DateTime(2026, 5, 30),
        end: DateTime(2026, 6, 12),
      );

      SharedPreferences.setMockInitialValues({
        'invoice_pdf_last_number_v1': staleNumber,
        'invoice_pdf_number_2026-05-30_2026-06-12': staleNumber,
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
}
