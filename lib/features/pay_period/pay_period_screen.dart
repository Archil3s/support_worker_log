// ignore_for_file: unused_element, deprecated_member_use, unused_local_variable
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/invoice_status.dart';
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

const int firstDisplayedInvoiceNumber = InvoicePdfService.firstInvoiceNumber;
const int futureInvoicePeriodsToDisplay = 26;

enum _InvoiceMoneyView { total, owed }

class PayPeriodScreen extends StatefulWidget {
  const PayPeriodScreen({super.key});

  @override
  State<PayPeriodScreen> createState() => _PayPeriodScreenState();
}

class _PayPeriodScreenState extends State<PayPeriodScreen> {
  late PayPeriodRange selectedRange;
  bool selectedRangeReady = false;
  _InvoiceMoneyView moneyView = _InvoiceMoneyView.total;

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
    selectedRange = currentFortnight(
      anchorDate: appState.settings.payPeriodAnchorDate,
    );

    selectedRangeReady = true;
  }

  PayPeriodRange? _latestInvoiceRange(
    List<WorkEntry> entries,
    DateTime? anchorDate,
  ) {
    return currentFortnight(anchorDate: anchorDate);
  }

  void selectInvoicePeriod(PayPeriodRange range) {
    setState(() => selectedRange = range);
  }

  void showLatestInvoicePeriod() {
    final appState = context.read<AppState>();

    setState(
      () => selectedRange = currentFortnight(
        anchorDate: appState.settings.payPeriodAnchorDate,
      ),
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
      return firstDisplayedInvoiceNumber;
    }

    final periodOffset =
        calendarDaysBetween(rows.first.range.start, selectedRange.start) ~/
        invoicePeriodDays;

    return rows.first.index + periodOffset;
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

  Future<void> _createSelectedTotalFolder({
    required BuildContext context,
    required int invoiceNumber,
    required List<WorkEntry> entries,
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
        content: Text('Creating Invoice $invoiceNumber total folder...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    try {
      final folder = await context
          .read<AppState>()
          .createInvoicePeriodTotalDriveFolder(
            invoiceNumber: invoiceNumber,
            range: selectedRange,
            entries: entries,
          );

      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice $invoiceNumber total folder ready.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              final opened = await _openDriveFolder(folder.id);
              if (!opened && context.mounted) {
                _showDriveOpenFailed(context);
              }
            },
          ),
        ),
      );
      final opened = await _openDriveFolder(folder.id);
      if (!opened && context.mounted) {
        _showDriveOpenFailed(context);
      }
    } catch (error) {
      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Total folder failed: $error'),
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
    final allInvoiceTotal = _invoiceRowsTotal(invoiceRows, settings);
    final owedInvoiceTotal = _invoiceRowsTotal(
      invoiceRows.where(
        (row) => appState.invoiceStatusForKey(_invoiceKey(row.range)).isOwed,
      ),
      settings,
    );
    final paidInvoiceTotal = _invoiceRowsTotal(
      invoiceRows.where(
        (row) => appState.invoiceStatusForKey(_invoiceKey(row.range)).isPaid,
      ),
      settings,
    );

    final visibleInvoiceRows = moneyView == _InvoiceMoneyView.owed
        ? invoiceRows
              .where(
                (row) =>
                    appState.invoiceStatusForKey(_invoiceKey(row.range)).isOwed,
              )
              .toList()
        : invoiceRows;
    final selectedInvoiceRowInList = invoiceRows.any(
      (row) => _sameRange(row.range, selectedRange),
    );

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
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedInvoiceRowInList
                    ? _invoiceKey(selectedRange)
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Pay period for notes',
                  prefixIcon: Icon(Icons.date_range_outlined),
                ),
                items: [
                  for (final row in invoiceRows)
                    DropdownMenuItem<String>(
                      value: _invoiceKey(row.range),
                      child: Text(
                        'Invoice ${row.index} | ${_formatReadableDate(row.range.start)} - ${_formatReadableDate(row.range.end)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final row = invoiceRows.firstWhere(
                    (item) => _invoiceKey(item.range) == value,
                  );
                  selectInvoicePeriod(row.range);
                },
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
          title: 'Invoice Money',
          child: _InvoiceMoneySummary(
            selectedView: moneyView,
            totalMoney: allInvoiceTotal,
            owedMoney: owedInvoiceTotal,
            paidMoney: paidInvoiceTotal,
            onChanged: (next) => setState(() => moneyView = next),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: moneyView == _InvoiceMoneyView.owed
              ? 'Money Owed - Submitted Invoices'
              : '2-Week Invoice Periods',
          child: _InvoicePeriodsTable(
            rows: visibleInvoiceRows,
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: periodEntries.isEmpty
              ? null
              : () => _createSelectedTotalFolder(
                  context: context,
                  invoiceNumber: selectedInvoiceNumber,
                  entries: periodEntries,
                ),
          icon: const Icon(Icons.drive_folder_upload_outlined),
          label: Text('Load Invoice $selectedInvoiceNumber Total Notes'),
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
  final anchorRange = fortnightForDate(
    anchorDate ?? defaultPayPeriodAnchorDate,
    anchorDate: anchorDate,
  );

  final currentRange = currentFortnight(anchorDate: anchorDate);
  final grouped = <DateTime, List<WorkEntry>>{};

  for (final entry in entries) {
    final range = fortnightForDate(entry.date, anchorDate: anchorDate);
    grouped.putIfAbsent(range.start, () => <WorkEntry>[]).add(entry);
  }

  var firstStart = anchorRange.start;

  if (grouped.isNotEmpty) {
    final firstEntryStart = grouped.keys.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );

    if (firstEntryStart.isBefore(firstStart)) {
      firstStart = firstEntryStart;
    }
  }

  var lastStart = currentRange.start;

  if (grouped.isNotEmpty) {
    final lastEntryStart = grouped.keys.reduce((a, b) => a.isAfter(b) ? a : b);

    if (lastEntryStart.isAfter(lastStart)) {
      lastStart = lastEntryStart;
    }
  }

  lastStart = addCalendarDays(
    lastStart,
    invoicePeriodDays * futureInvoicePeriodsToDisplay,
  );

  final rows = <_InvoicePeriodRow>[];
  var start = firstStart;
  var invoiceNumber = firstDisplayedInvoiceNumber;

  while (!start.isAfter(lastStart)) {
    final periodEntries = (grouped[start] ?? <WorkEntry>[]).toList()
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;

        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });

    rows.add(
      _InvoicePeriodRow(
        index: invoiceNumber,
        range: PayPeriodRange(
          start: start,
          end: addCalendarDays(start, invoicePeriodDays - 1),
        ),
        entries: periodEntries,
      ),
    );

    start = addCalendarDays(start, invoicePeriodDays);
    invoiceNumber++;
  }

  return rows;
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
    return firstDisplayedInvoiceNumber;
  }

  final periodOffset =
      calendarDaysBetween(rows.first.range.start, selectedRange.start) ~/
      invoicePeriodDays;

  return rows.first.index + periodOffset;
}

class _InvoiceMoneySummary extends StatelessWidget {
  const _InvoiceMoneySummary({
    required this.selectedView,
    required this.totalMoney,
    required this.owedMoney,
    required this.paidMoney,
    required this.onChanged,
  });

  final _InvoiceMoneyView selectedView;
  final double totalMoney;
  final double owedMoney;
  final double paidMoney;
  final ValueChanged<_InvoiceMoneyView> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = selectedView == _InvoiceMoneyView.total
        ? totalMoney
        : owedMoney;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_InvoiceMoneyView>(
          segments: const [
            ButtonSegment<_InvoiceMoneyView>(
              value: _InvoiceMoneyView.total,
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: Text('Total Money'),
            ),
            ButtonSegment<_InvoiceMoneyView>(
              value: _InvoiceMoneyView.owed,
              icon: Icon(Icons.pending_actions_outlined),
              label: Text('Money Owed'),
            ),
          ],
          selected: {selectedView},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
        const SizedBox(height: 14),
        Text(
          money(selectedValue),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          selectedView == _InvoiceMoneyView.total
              ? 'Total value of all invoice periods'
              : 'Submitted invoices not marked as paid',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8396C7),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _MoneyChip(label: 'Total', value: totalMoney),
            _MoneyChip(label: 'Owed', value: owedMoney),
            _MoneyChip(label: 'Paid', value: paidMoney),
          ],
        ),
      ],
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${money(value)}'),
      side: const BorderSide(color: Color(0xFF34405F)),
      backgroundColor: const Color(0xFF20283B),
      labelStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }
}

class _InvoiceStatusPill extends StatelessWidget {
  const _InvoiceStatusPill({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _invoiceStatusColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _InvoiceStatusButtons extends StatelessWidget {
  const _InvoiceStatusButtons({required this.status, required this.onChanged});

  final InvoiceStatus status;
  final ValueChanged<InvoiceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatusButton(
          label: 'Not Submitted',
          icon: Icons.radio_button_unchecked,
          selected: status == InvoiceStatus.notSubmitted,
          color: _invoiceStatusColor(InvoiceStatus.notSubmitted),
          onTap: () => onChanged(InvoiceStatus.notSubmitted),
        ),
        _StatusButton(
          label: 'Submitted',
          icon: Icons.upload_file_outlined,
          selected: status == InvoiceStatus.submitted,
          color: _invoiceStatusColor(InvoiceStatus.submitted),
          onTap: () => onChanged(InvoiceStatus.submitted),
        ),
        _StatusButton(
          label: 'Paid',
          icon: Icons.check_circle_outline,
          selected: status == InvoiceStatus.paid,
          color: _invoiceStatusColor(InvoiceStatus.paid),
          onTap: () => onChanged(InvoiceStatus.paid),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: selected ? color : Colors.white70),
      label: Text(label),
      onPressed: onTap,
      side: BorderSide(color: color),
      backgroundColor: selected ? color.withOpacity(0.18) : Colors.transparent,
      labelStyle: TextStyle(
        color: selected ? color : Colors.white70,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );
  }
}

String _invoiceKey(PayPeriodRange range) {
  return '${_keyDate(range.start)}_${_keyDate(range.end)}';
}

String _keyDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

double _invoiceRowsTotal(
  Iterable<_InvoicePeriodRow> rows,
  AppSettings settings,
) {
  return rows.fold<double>(
    0,
    (total, row) => total + _invoiceTotal(row.entries, settings),
  );
}

double _invoiceTotal(List<WorkEntry> entries, AppSettings settings) {
  return totalEarnings(entries, settings) +
      (totalKilometres(entries) * settings.fuelRate);
}

String _signedMoney(double value) {
  final prefix = value >= 0 ? '+' : '-';
  return '$prefix${money(value.abs())}';
}

Color _invoiceStatusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.notSubmitted:
      return const Color(0xFF8396C7);
    case InvoiceStatus.submitted:
      return const Color(0xFFFFC857);
    case InvoiceStatus.paid:
      return const Color(0xFF22C55E);
  }
}

Color _invoiceStatusBackground(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.notSubmitted:
      return Colors.transparent;
    case InvoiceStatus.submitted:
      return const Color(0xFF2A2413);
    case InvoiceStatus.paid:
      return const Color(0xFF102A1C);
  }
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

  Future<void> _createTotalFolderFromMenu(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    if (row.entries.isEmpty) {
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
        content: Text('Creating Invoice ${row.index} total folder...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    try {
      final folder = await context
          .read<AppState>()
          .createInvoicePeriodTotalDriveFolder(
            invoiceNumber: row.index,
            range: row.range,
            entries: row.entries,
          );

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice ${row.index} total folder ready.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              final opened = await _openDriveFolder(folder.id);
              if (!opened && context.mounted) {
                _showDriveOpenFailed(context);
              }
            },
          ),
        ),
      );
      final opened = await _openDriveFolder(folder.id);
      if (!opened && context.mounted) {
        _showDriveOpenFailed(context);
      }
    } catch (error) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Total folder failed: $error'),
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
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final invoiceKey = _invoiceKey(row.range);
    final invoiceStatus = appState.invoiceStatusForKey(invoiceKey);
    final invoiceTotal = _invoiceTotal(row.entries, settings);
    final invoiceBaseline = appState.invoiceBaselineTotalForKey(invoiceKey);
    final invoiceDelta = invoiceBaseline == null
        ? null
        : invoiceTotal - invoiceBaseline;
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
          color: isSelected
              ? const Color(0xFF20283B)
              : _invoiceStatusBackground(invoiceStatus),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5B8CFF)
                : _invoiceStatusColor(invoiceStatus),
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
                  if (invoiceDelta != null &&
                      invoiceStatus != InvoiceStatus.notSubmitted &&
                      invoiceDelta.abs() >= 0.01) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Change since marked ${invoiceStatus.label.toLowerCase()}: '
                      '${_signedMoney(invoiceDelta)}',
                      style: TextStyle(
                        color: invoiceDelta >= 0
                            ? const Color(0xFFFFC857)
                            : const Color(0xFF31E981),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                IconButton(
                  tooltip: 'Create total Drive folder',
                  onPressed: () => _createTotalFolderFromMenu(context),
                  icon: const Icon(Icons.drive_folder_upload_outlined),
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
    final appState = context.watch<AppState>();
    final settings = appState.settings;

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
            SectionCard(
              title: 'Invoice Status',
              child: _InvoiceStatusEditor(
                range: row.range,
                invoiceTotal: _invoiceTotal(entries, settings),
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

class _InvoiceStatusEditor extends StatelessWidget {
  const _InvoiceStatusEditor({required this.range, required this.invoiceTotal});

  final PayPeriodRange range;
  final double invoiceTotal;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final invoiceKey = _invoiceKey(range);
    final status = appState.invoiceStatusForKey(invoiceKey);
    final baselineTotal = appState.invoiceBaselineTotalForKey(invoiceKey);
    final invoiceDelta = baselineTotal == null
        ? null
        : invoiceTotal - baselineTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InvoiceStatusPill(status: status),
        const SizedBox(height: 10),
        Text(
          'Invoice total: ${money(invoiceTotal)}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        if (baselineTotal != null && status != InvoiceStatus.notSubmitted) ...[
          const SizedBox(height: 6),
          Text(
            'Marked ${status.label.toLowerCase()} at ${money(baselineTotal)}',
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (invoiceDelta != null && invoiceDelta.abs() >= 0.01)
            Text(
              'Current change: ${_signedMoney(invoiceDelta)}',
              style: TextStyle(
                color: invoiceDelta >= 0
                    ? const Color(0xFFFFC857)
                    : const Color(0xFF31E981),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
        const SizedBox(height: 12),
        _InvoiceStatusButtons(
          status: status,
          onChanged: (next) => context.read<AppState>().updateInvoiceStatus(
            invoiceKey,
            next,
            currentTotal: invoiceTotal,
          ),
        ),
      ],
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
  return '${_formatNumericDate(range.start)} - ${_formatNumericDate(range.end)}';
}

Future<bool> _openDriveFolder(String folderId) async {
  final id = folderId.trim();
  if (id.isEmpty) return false;

  return launchUrl(
    Uri.parse(
      'https://drive.google.com/drive/folders/${Uri.encodeComponent(id)}',
    ),
    webOnlyWindowName: '_blank',
  );
}

void _showDriveOpenFailed(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: const Text(
          'Google Drive folder is ready, but the browser blocked opening it.',
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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
