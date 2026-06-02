import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/general_action.dart';
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

  test('persists mixed general actions', () {
    final createdAt = DateTime(2026, 6, 2, 9);
    final completedAt = DateTime(2026, 6, 2, 10);
    final data = StoredAppData(
      settings: const AppSettings(),
      clients: const ['AB'],
      entries: const [],
      generalActions: [
        GeneralActionItem(
          id: 'action-1',
          title: 'Check consent wording',
          scope: GeneralActionScope.knowledgeGap,
          createdAt: createdAt,
          completedAt: completedAt,
        ),
        GeneralActionItem(
          id: 'action-2',
          title: 'Call GP',
          scope: GeneralActionScope.client,
          client: 'AB',
          createdAt: createdAt,
        ),
      ],
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.generalActions, hasLength(2));
    expect(
      restored.generalActions.first.scope,
      GeneralActionScope.knowledgeGap,
    );
    expect(restored.generalActions.first.completedAt, completedAt);
    expect(restored.generalActions.last.client, 'AB');
  });
}
