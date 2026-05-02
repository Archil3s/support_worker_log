import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onQuickEntry,
    required this.onPayPeriod,
    required this.onEntries,
  });

  final VoidCallback onQuickEntry;
  final VoidCallback onPayPeriod;
  final VoidCallback onEntries;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final entries = appState.entries;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final todayEntries = entriesBetween(entries, todayOnly, todayOnly);

    final currentRange = currentFortnight();
    final periodEntries = entriesInRange(entries, currentRange);

    final lastEntry = _latestEntry(entries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Today',
          child: StatGrid(
            cards: [
              StatCard(title: 'Entries', value: '${todayEntries.length}'),
              StatCard(
                title: 'Hours',
                value: totalHours(todayEntries).toStringAsFixed(2),
              ),
              StatCard(
                title: 'Earned',
                value: money(totalEarnings(todayEntries, settings)),
              ),
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
                '${formatDate(currentRange.start)} - ${formatDate(currentRange.end)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              StatGrid(
                cards: [
                  StatCard(title: 'Entries', value: '${periodEntries.length}'),
                  StatCard(
                    title: 'Hours',
                    value: totalHours(periodEntries).toStringAsFixed(2),
                  ),
                  StatCard(
                    title: 'Earned',
                    value: money(totalEarnings(periodEntries, settings)),
                  ),
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
                label: const Text('Log New Entry'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onPayPeriod,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('View Pay Period'),
              ),
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
              ? const EmptyState(
                  message: 'No entries yet. Use Quick Entry to start logging.',
                )
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(entry.type.icon)),
          title: Text(entry.client),
          subtitle: Text(
            '${entry.type.label} • ${formatDate(entry.date)} • ${formatTime(entry.startTime)} • ${entry.minutes} min',
          ),
          trailing: Text(money(entry.earnings(settings))),
        ),
        if (entry.notes.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final note in entry.notes)
                Chip(label: Text(note), visualDensity: VisualDensity.compact),
            ],
          ),
      ],
    );
  }
}
