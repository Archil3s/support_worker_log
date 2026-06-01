import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/invoice_status.dart';
import 'package:support_worker_log/core/services/storage_service.dart';

void main() {
  test('persists invoice status baselines', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['AB'],
      entries: [],
      invoiceStatuses: {'2026-06-01_2026-06-14': InvoiceStatus.submitted},
      invoiceBaselineTotals: {'2026-06-01_2026-06-14': 125.75},
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(
      restored.invoiceStatuses['2026-06-01_2026-06-14'],
      InvoiceStatus.submitted,
    );
    expect(restored.invoiceBaselineTotals['2026-06-01_2026-06-14'], 125.75);
  });
}
