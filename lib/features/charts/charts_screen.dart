import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.entries;
    final settings = appState.settings;
    final earnings = totalEarnings(entries, settings);
    final average = entries.isEmpty ? 0 : earnings / entries.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatGrid(
          cards: [
            StatCard(title: 'Entries', value: '${entries.length}'),
            StatCard(
              title: 'Hours',
              value: totalHours(entries).toStringAsFixed(2),
            ),
            StatCard(title: 'Earned', value: money(earnings)),
            StatCard(
              title: 'KM',
              value: totalKilometres(entries).toStringAsFixed(1),
            ),
            StatCard(title: 'Avg / Entry', value: money(average.toDouble())),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Activity Snapshot',
          child: Column(
            children: [
              if (entries.isEmpty)
                const EmptyState(
                  message: 'Charts will populate after entries are saved.',
                ),
              for (final type in EntryType.values)
                ReviewRow(
                  label: type.label,
                  value:
                      '${entries.where((entry) => entry.type == type).length}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
