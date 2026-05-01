import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class PayPeriodScreen extends StatelessWidget {
  const PayPeriodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 13));

    final periodEntries = appState.entries.where((entry) {
      final entryDate = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      return !entryDate.isBefore(start);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Current 14-day period',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text('${formatDate(start)} - ${formatDate(now)}'),
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
              value: money(totalEarnings(periodEntries, appState.settings)),
            ),
            StatCard(
              title: 'KM',
              value: totalKilometres(periodEntries).toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Daily Breakdown',
          child: Column(
            children: [
              if (periodEntries.isEmpty)
                const EmptyState(message: 'No entries in this period yet.'),
              for (final entry in periodEntries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(entry.type.icon),
                  title: Text('${entry.client} - ${entry.type.label}'),
                  subtitle: Text(
                    '${formatDate(entry.date)} • ${entry.minutes} min',
                  ),
                  trailing: Text(money(entry.earnings(appState.settings))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
