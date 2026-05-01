import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';

class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.entries;
    final settings = appState.settings;

    if (entries.isEmpty) {
      return const EmptyState(
        message: 'No entries yet. Use Quick Entry to save your first log.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(entry.type.icon)),
                  title: Text(entry.client),
                  subtitle: Text(
                    '${entry.type.label} • ${formatDate(entry.date)} • ${entry.minutes} min',
                  ),
                  trailing: Text(money(entry.earnings(settings))),
                ),
                if (entry.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final note in entry.notes)
                          Chip(
                            label: Text(note),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: entry.textSummary(settings)),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entry copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        context.read<AppState>().duplicateEntry(entry);
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Duplicate'),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        final removed = context.read<AppState>().deleteEntry(
                          entry,
                        );
                        if (removed == null) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Entry deleted'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                context.read<AppState>().restoreEntry(removed);
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
