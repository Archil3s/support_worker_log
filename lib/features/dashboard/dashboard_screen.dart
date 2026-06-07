import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/google_account_connection_card.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onQuickEntry,
    required this.onPayPeriod,
    required this.onEntries,
    required this.onAdminReview,
  });

  final VoidCallback onQuickEntry;
  final VoidCallback onPayPeriod;
  final VoidCallback onEntries;
  final VoidCallback onAdminReview;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final entries = appState.entries;
    final payeMode = appState.isPayeMode;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final todayEntries = entriesBetween(entries, todayOnly, todayOnly);

    final range = currentFortnight(anchorDate: settings.payPeriodAnchorDate);
    final periodEntries = entriesInRange(entries, range);
    final lastEntry = _latestEntry(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GoogleAccountConnectionCard(
          scope: payeMode
              ? GoogleExportAccountScope.paye
              : GoogleExportAccountScope.work,
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Today',
          child: StatGrid(
            cards: [
              StatCard(title: 'Entries', value: '${todayEntries.length}'),
              StatCard(
                title: 'Hours',
                value: totalHours(todayEntries).toStringAsFixed(2),
              ),
              if (!payeMode)
                StatCard(
                  title: 'Earned',
                  value: money(totalEarnings(todayEntries, settings)),
                ),
              if (!payeMode)
                StatCard(
                  title: 'KM',
                  value: totalKilometres(todayEntries).toStringAsFixed(1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Current Fortnight',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(range.start)} - ${formatDate(range.end)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              StatGrid(
                cards: [
                  StatCard(title: 'Entries', value: '${periodEntries.length}'),
                  StatCard(
                    title: 'Hours',
                    value: totalHours(periodEntries).toStringAsFixed(2),
                  ),
                  if (!payeMode)
                    StatCard(
                      title: 'Earned',
                      value: money(totalEarnings(periodEntries, settings)),
                    ),
                  if (!payeMode)
                    StatCard(
                      title: 'KM',
                      value: totalKilometres(periodEntries).toStringAsFixed(1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Quick Actions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onQuickEntry,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Start / Finish Visit'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onAdminReview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Admin Review'),
              ),
              if (!payeMode) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: onPayPeriod,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('View Pay Period'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onEntries,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('View Entries'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Last Entry',
          child: lastEntry == null
              ? const EmptyState(message: 'No entries yet.')
              : _LastEntryCard(entry: lastEntry),
        ),
      ],
    );
  }

  WorkEntry? _latestEntry(List<WorkEntry> entries) {
    if (entries.isEmpty) return null;

    final sorted = entries.toList()
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;

        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return bMinutes.compareTo(aMinutes);
      });

    return sorted.first;
  }
}

class _LastEntryCard extends StatelessWidget {
  const _LastEntryCard({required this.entry});

  final WorkEntry entry;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final payeMode = context.watch<AppState>().isPayeMode;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(entry.type.icon)),
      title: Text(entry.client),
      subtitle: Text(
        '${entry.type.label} | ${formatDate(entry.date)} | ${entry.minutes} min',
      ),
      trailing: Text(
        payeMode ? '${entry.baseMinutes} min' : money(entry.earnings(settings)),
      ),
    );
  }
}
