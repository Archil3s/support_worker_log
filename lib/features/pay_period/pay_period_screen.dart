import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/models/app_settings.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

const int firstDisplayedInvoiceNumber = 10;

class PayPeriodScreen extends StatefulWidget {
  const PayPeriodScreen({super.key});

  @override
  State<PayPeriodScreen> createState() => _PayPeriodScreenState();
}

class _PayPeriodScreenState extends State<PayPeriodScreen> {
  late PayPeriodRange selectedRange;
  bool selectedRangeReady = false;

  @override
  void initState() {
    super.initState();
    selectedRange = PayPeriodRange(
      start: DateTime(2025, 12, 14),
      end: DateTime(2025, 12, 27),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (selectedRangeReady) return;

    final appState = context.read<AppState>();
    selectedRange =
        _latestInvoiceRange(
          appState.entries,
          appState.settings.payPeriodAnchorDate,
        ) ??
        currentFortnight(anchorDate: appState.settings.payPeriodAnchorDate);

    selectedRangeReady = true;
  }

  PayPeriodRange? _latestInvoiceRange(
    List<WorkEntry> entries,
    DateTime? anchorDate,
  ) {
    final rows = _invoicePeriodRows(entries, anchorDate);
    if (rows.isEmpty) return null;
    return rows.last.range;
  }

  void selectInvoicePeriod(PayPeriodRange range) {
    setState(() => selectedRange = range);
  }

  void showLatestInvoicePeriod() {
    final appState = context.read<AppState>();
    final latestRange = _latestInvoiceRange(
      appState.entries,
      appState.settings.payPeriodAnchorDate,
    );

    setState(
      () => selectedRange =
          latestRange ??
          currentFortnight(anchorDate: appState.settings.payPeriodAnchorDate),
    );
  }

  void showPreviousPeriod() {
    setState(() => selectedRange = selectedRange.previous);
  }

  void showNextPeriod() {
    setState(() => selectedRange = selectedRange.next);
  }

  int _invoiceNumberForSelectedRange(List<_InvoicePeriodRow> rows) {
    for (final row in rows) {
      if (_sameRange(row.range, selectedRange)) {
        return row.index;
      }
    }

    if (rows.isEmpty) {
      return 1;
    }

    return rows.length + 1;
  }

  Future<void> _exportSelectedInvoice({
    required BuildContext context,
    required int invoiceNumber,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    if (entries.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('No entries in this invoice period.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Building Invoice $invoiceNumber PDF...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    try {
      await InvoicePdfService.exportInvoice(
        invoiceNumber: invoiceNumber,
        period: selectedRange,
        entries: entries,
        settings: settings,
      );

      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice $invoiceNumber PDF created.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice export failed: $error'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final invoiceRows = _invoicePeriodRows(
      appState.entries,
      settings.payPeriodAnchorDate,
    );

    final periodEntries = entriesInRange(appState.entries, selectedRange);
    final weekOneEntries = entriesBetween(
      appState.entries,
      selectedRange.weekOneStart,
      selectedRange.weekOneEnd,
    );
    final weekTwoEntries = entriesBetween(
      appState.entries,
      selectedRange.weekTwoStart,
      selectedRange.weekTwoEnd,
    );
    final selectedInvoiceNumber = _invoiceNumberForSelectedRange(invoiceRows);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '2-Week Invoice Selector',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(selectedRange.start)} - ${formatDate(selectedRange.end)}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: showPreviousPeriod,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: showLatestInvoicePeriod,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Latest 2-Week Invoice'),
                  ),
                  OutlinedButton.icon(
                    onPressed: showNextPeriod,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '2-Week Invoice Periods',
          child: _InvoicePeriodsTable(
            rows: invoiceRows,
            selectedRange: selectedRange,
            onSelected: selectInvoicePeriod,
          ),
        ),
        const SizedBox(height: 16),
        StatGrid(
          cards: [
            StatCard(title: 'Entries', value: '${periodEntries.length}'),
            StatCard(
              title: 'Hours',
              value: totalHours(periodEntries).toStringAsFixed(2),
            ),
            StatCard(
              title: 'Earnings',
              value: money(totalEarnings(periodEntries, settings)),
            ),
            StatCard(
              title: 'KM',
              value: totalKilometres(periodEntries).toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: periodEntries.isEmpty
              ? null
              : () => _exportSelectedInvoice(
                  context: context,
                  invoiceNumber: selectedInvoiceNumber,
                  entries: periodEntries,
                  settings: settings,
                ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text('Build Invoice $selectedInvoiceNumber PDF'),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Week 1 of 2-Week Invoice',
          child: _WeekBreakdown(
            start: selectedRange.weekOneStart,
            end: selectedRange.weekOneEnd,
            entries: weekOneEntries,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Week 2 of 2-Week Invoice',
          child: _WeekBreakdown(
            start: selectedRange.weekTwoStart,
            end: selectedRange.weekTwoEnd,
            entries: weekTwoEntries,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Daily Breakdown',
          child: _DailyBreakdown(entries: periodEntries),
        ),
      ],
    );
  }
}

class _InvoicePeriodRow {
  const _InvoicePeriodRow({
    required this.index,
    required this.range,
    required this.entries,
  });

  final int index;
  final PayPeriodRange range;
  final List<WorkEntry> entries;
}

List<_InvoicePeriodRow> _invoicePeriodRows(
  List<WorkEntry> entries,
  DateTime? anchorDate,
) {
  if (entries.isEmpty) return const [];

  final grouped = <DateTime, List<WorkEntry>>{};

  for (final entry in entries) {
    final range = fortnightForDate(entry.date, anchorDate: anchorDate);
    grouped.putIfAbsent(range.start, () => <WorkEntry>[]).add(entry);
  }

  final starts = grouped.keys.toList()..sort();

  return [
    for (var index = 0; index < starts.length; index++)
      _InvoicePeriodRow(
        index: index + 1,
        range: PayPeriodRange(
          start: starts[index],
          end: starts[index].add(const Duration(days: 13)),
        ),
        entries: grouped[starts[index]]!
          ..sort((a, b) => a.date.compareTo(b.date)),
      ),
  ];
}

int _invoiceNumberForRange(
  List<_InvoicePeriodRow> rows,
  PayPeriodRange selectedRange,
) {
  for (final row in rows) {
    if (_sameRange(row.range, selectedRange)) {
      return row.index;
    }
  }

  if (rows.isEmpty) {
    return 1;
  }

  return rows.length + 1;
}

class _InvoicePeriodsTable extends StatelessWidget {
  const _InvoicePeriodsTable({
    required this.rows,
    required this.selectedRange,
    required this.onSelected,
  });

  final List<_InvoicePeriodRow> rows;
  final PayPeriodRange selectedRange;
  final ValueChanged<PayPeriodRange> onSelected;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyState(message: 'No invoice periods yet.');
    }

    return Column(
      children: [
        for (final row in rows) ...[
          _InvoicePeriodTile(
            row: row,
            selectedRange: selectedRange,
            onSelected: onSelected,
          ),
          if (row != rows.last) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _InvoicePeriodTile extends StatelessWidget {
  const _InvoicePeriodTile({
    required this.row,
    required this.selectedRange,
    required this.onSelected,
  });

  final _InvoicePeriodRow row;
  final PayPeriodRange selectedRange;
  final ValueChanged<PayPeriodRange> onSelected;

  Future<void> _exportInvoiceFromMenu(
    BuildContext context,
    AppSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    if (row.entries.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('No entries to export for this invoice period.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Exporting Invoice ${row.index}...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    try {
      await InvoicePdfService.exportInvoice(
        invoiceNumber: row.index,
        period: row.range,
        entries: row.entries,
        settings: settings,
      );

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice ${row.index} PDF ready.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (error) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice export failed: $error'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  void _openBreakdown(BuildContext context) {
    onSelected(row.range);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InvoiceBreakdownSheet(row: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _sameRange(row.range, selectedRange);
    final settings = context.watch<AppState>().settings;
    final hours = totalHours(row.entries);
    final km = totalKilometres(row.entries);
    final hoursText = hours.toStringAsFixed(2);
    final kmText = km.toStringAsFixed(1);
    final hoursMoney = money(totalEarnings(row.entries, settings));
    final travelMoney = money(km * settings.fuelRate);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openBreakdown(context),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20283B) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B8CFF) : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(
                '${row.index}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatReadableDate(row.range.start)} - ${_formatReadableDate(row.range.end)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.entries.length} entries | $hoursText hrs = $hoursMoney',
                    style: const TextStyle(color: Color(0xFF8396C7)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$kmText km travel = $travelMoney',
                    style: const TextStyle(color: Color(0xFF8396C7)),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Selected in Fortnight Selector',
                      style: TextStyle(
                        color: Color(0xFF5B8CFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Export invoice PDF',
                  onPressed: () => _exportInvoiceFromMenu(context, settings),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceBreakdownSheet extends StatelessWidget {
  const _InvoiceBreakdownSheet({required this.row});

  final _InvoicePeriodRow row;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

    final entries = row.entries.toList()
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;

        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });

    final weekOneEntries = entriesBetween(
      entries,
      row.range.weekOneStart,
      row.range.weekOneEnd,
    );

    final weekTwoEntries = entriesBetween(
      entries,
      row.range.weekTwoStart,
      row.range.weekTwoEnd,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Invoice ${row.index}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatInvoiceDateRange(row.range),
              style: const TextStyle(
                color: Color(0xFF8396C7),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            StatGrid(
              cards: [
                StatCard(title: 'Entries', value: '${entries.length}'),
                StatCard(
                  title: 'Hours',
                  value: totalHours(entries).toStringAsFixed(2),
                ),
                StatCard(
                  title: 'Earnings',
                  value: money(totalEarnings(entries, settings)),
                ),
                StatCard(
                  title: 'KM',
                  value: totalKilometres(entries).toStringAsFixed(1),
                ),
                StatCard(
                  title: 'Travel \$',
                  value: money(totalKilometres(entries) * settings.fuelRate),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Week 1 of 2-Week Invoice',
              child: _WeekBreakdown(
                start: row.range.weekOneStart,
                end: row.range.weekOneEnd,
                entries: weekOneEntries,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Week 2 of 2-Week Invoice',
              child: _WeekBreakdown(
                start: row.range.weekTwoStart,
                end: row.range.weekTwoEnd,
                entries: weekTwoEntries,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Client Breakdown',
              child: _InvoiceClientBreakdown(entries: entries),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Daily Breakdown',
              child: _DailyBreakdown(entries: entries),
            ),
          ],
        );
      },
    );
  }
}

class _InvoiceClientBreakdown extends StatelessWidget {
  const _InvoiceClientBreakdown({required this.entries});

  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final totals = _clientTotals(entries, settings);

    if (totals.isEmpty) {
      return const EmptyState(message: 'No client entries in this invoice.');
    }

    return Column(
      children: [
        for (final total in totals) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              total.client,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${total.entries} entries | ${total.hours.toStringAsFixed(2)} hrs | ${total.kilometres.toStringAsFixed(1)} km',
            ),
            trailing: Text(
              money(total.earnings),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (total != totals.last) const Divider(height: 1),
        ],
      ],
    );
  }

  List<_InvoiceClientTotal> _clientTotals(
    List<WorkEntry> entries,
    dynamic settings,
  ) {
    final map = <String, _InvoiceClientTotal>{};

    for (final entry in entries) {
      final existing =
          map[entry.client] ??
          _InvoiceClientTotal(
            client: entry.client,
            entries: 0,
            hours: 0,
            kilometres: 0,
            earnings: 0,
          );

      map[entry.client] = existing.copyWith(
        entries: existing.entries + 1,
        hours: existing.hours + entry.hours,
        kilometres: existing.kilometres + entry.kilometres,
        earnings: existing.earnings + entry.earnings(settings),
      );
    }

    final totals = map.values.toList()
      ..sort((a, b) => b.earnings.compareTo(a.earnings));

    return totals;
  }
}

class _InvoiceClientTotal {
  const _InvoiceClientTotal({
    required this.client,
    required this.entries,
    required this.hours,
    required this.kilometres,
    required this.earnings,
  });

  final String client;
  final int entries;
  final double hours;
  final double kilometres;
  final double earnings;

  _InvoiceClientTotal copyWith({
    int? entries,
    double? hours,
    double? kilometres,
    double? earnings,
  }) {
    return _InvoiceClientTotal(
      client: client,
      entries: entries ?? this.entries,
      hours: hours ?? this.hours,
      kilometres: kilometres ?? this.kilometres,
      earnings: earnings ?? this.earnings,
    );
  }
}

bool _sameRange(PayPeriodRange a, PayPeriodRange b) {
  return _sameDate(a.start, b.start) && _sameDate(a.end, b.end);
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatInvoiceDateRange(PayPeriodRange range) {
  return '${_formatNumericDate(range.start)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ${_formatNumericDate(range.end)}';
}

String _formatNumericDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatReadableDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _WeekBreakdown extends StatelessWidget {
  const _WeekBreakdown({
    required this.start,
    required this.end,
    required this.entries,
  });

  final DateTime start;
  final DateTime end;
  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${formatDate(start)} - ${formatDate(end)}'),
        const SizedBox(height: 12),
        ReviewRow(label: 'Entries', value: '${entries.length}'),
        ReviewRow(
          label: 'Hours',
          value: totalHours(entries).toStringAsFixed(2),
        ),
        ReviewRow(
          label: 'Earnings',
          value: money(totalEarnings(entries, settings)),
        ),
        ReviewRow(
          label: 'KM',
          value: totalKilometres(entries).toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({required this.entries});

  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

    if (entries.isEmpty) {
      return const EmptyState(message: 'No entries in this pay period yet.');
    }

    final grouped = groupEntriesByDay(entries);

    return Column(
      children: [
        for (final dayGroup in grouped.entries) ...[
          _DayHeader(day: dayGroup.key, entries: dayGroup.value),
          for (final entry in dayGroup.value)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(entry.type.icon),
              title: Text('${entry.client} - ${entry.type.label}'),
              subtitle: Text(
                '${formatTime(entry.startTime)} - ${entry.baseMinutes} min | time ${entry.hours.toStringAsFixed(2)}h',
              ),
              trailing: Text(money(entry.earnings(settings))),
            ),
          if (dayGroup.key != grouped.keys.last) const Divider(),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.entries});

  final DateTime day;
  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatDate(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '${totalHours(entries).toStringAsFixed(2)} hrs - ${money(totalEarnings(entries, settings))}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
