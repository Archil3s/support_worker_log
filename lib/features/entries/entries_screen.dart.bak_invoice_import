import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'edit_entry_sheet.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  final searchController = TextEditingController();

  String searchQuery = '';
  _EntryTypeFilter typeFilter = _EntryTypeFilter.all;
  _EntryDateFilter dateFilter = _EntryDateFilter.all;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool get hasActiveFilters {
    return searchQuery.trim().isNotEmpty ||
        typeFilter != _EntryTypeFilter.all ||
        dateFilter != _EntryDateFilter.all;
  }

  Future<void> _openEditSheet({
    required BuildContext context,
    required WorkEntry entry,
  }) async {
    final appState = context.read<AppState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return EditEntrySheet(
          entry: entry,
          clients: appState.clients,
          onSave: (updatedEntry) {
            appState.updateEntry(updatedEntry);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Entry updated')));
          },
        );
      },
    );
  }

  List<WorkEntry> _filteredEntries(List<WorkEntry> entries) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final selectedType = typeFilter.entryType;

    return entries.where((entry) {
      final matchesSearch =
          normalizedQuery.isEmpty ||
          entry.client.toLowerCase().contains(normalizedQuery) ||
          entry.type.label.toLowerCase().contains(normalizedQuery) ||
          entry.notes.any(
            (note) => note.toLowerCase().contains(normalizedQuery),
          );

      final matchesType = selectedType == null || entry.type == selectedType;
      final matchesDate = _matchesDateFilter(entry);

      return matchesSearch && matchesType && matchesDate;
    }).toList();
  }

  bool _matchesDateFilter(WorkEntry entry) {
    switch (dateFilter) {
      case _EntryDateFilter.all:
        return true;
      case _EntryDateFilter.currentFortnight:
        return currentFortnight().contains(entry.date);
      case _EntryDateFilter.previousFortnight:
        return currentFortnight().previous.contains(entry.date);
      case _EntryDateFilter.last30Days:
        final today = DateTime.now();
        final end = DateTime(today.year, today.month, today.day);
        final start = end.subtract(const Duration(days: 29));
        final entryDay = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );

        return !entryDay.isBefore(start) && !entryDay.isAfter(end);
    }
  }

  void _clearFilters() {
    setState(() {
      searchController.clear();
      searchQuery = '';
      typeFilter = _EntryTypeFilter.all;
      dateFilter = _EntryDateFilter.all;
    });
  }

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

    final filteredEntries = _filteredEntries(entries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FilterSection(
          searchController: searchController,
          searchQuery: searchQuery,
          typeFilter: typeFilter,
          dateFilter: dateFilter,
          hasActiveFilters: hasActiveFilters,
          onSearchChanged: (value) => setState(() => searchQuery = value),
          onClearSearch: () {
            setState(() {
              searchController.clear();
              searchQuery = '';
            });
          },
          onTypeFilterChanged: (value) {
            setState(() => typeFilter = value ?? _EntryTypeFilter.all);
          },
          onDateFilterChanged: (value) {
            setState(() => dateFilter = value ?? _EntryDateFilter.all);
          },
          onClearFilters: _clearFilters,
        ),
        const SizedBox(height: 12),
        StatGrid(
          cards: [
            StatCard(
              title: 'Showing',
              value: '${filteredEntries.length}/${entries.length}',
            ),
            StatCard(
              title: 'Hours',
              value: totalHours(filteredEntries).toStringAsFixed(2),
            ),
            StatCard(
              title: 'Earnings',
              value: money(totalEarnings(filteredEntries, settings)),
            ),
            StatCard(
              title: 'KM',
              value: totalKilometres(filteredEntries).toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredEntries.isEmpty)
          SectionCard(
            title: 'Results',
            child: EmptyState(
              message: hasActiveFilters
                  ? 'No entries match these filters.'
                  : 'No entries to show.',
            ),
          )
        else
          for (final entry in filteredEntries) ...[
            _EntryCard(
              entry: entry,
              onEdit: () => _openEditSheet(context: context, entry: entry),
            ),
            if (entry != filteredEntries.last) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.searchController,
    required this.searchQuery,
    required this.typeFilter,
    required this.dateFilter,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTypeFilterChanged,
    required this.onDateFilterChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final _EntryTypeFilter typeFilter;
  final _EntryDateFilter dateFilter;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_EntryTypeFilter?> onTypeFilterChanged;
  final ValueChanged<_EntryDateFilter?> onDateFilterChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Search & Filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search_outlined),
              labelText: 'Search entries',
              helperText: 'Search by client, note, or entry type',
              suffixIcon: searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_EntryTypeFilter>(
            initialValue: typeFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Entry type',
            ),
            items: [
              for (final filter in _EntryTypeFilter.values)
                DropdownMenuItem<_EntryTypeFilter>(
                  value: filter,
                  child: Text(filter.label),
                ),
            ],
            onChanged: onTypeFilterChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_EntryDateFilter>(
            initialValue: dateFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Date range',
            ),
            items: [
              for (final filter in _EntryDateFilter.values)
                DropdownMenuItem<_EntryDateFilter>(
                  value: filter,
                  child: Text(filter.label),
                ),
            ],
            onChanged: onDateFilterChanged,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onEdit});

  final WorkEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

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
                '${entry.type.label} ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${formatDate(entry.date)} ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${entry.minutes} min',
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
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
                IconButton(
                  onPressed: () {
                    final removed = context.read<AppState>().deleteEntry(entry);
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
  }
}

enum _EntryTypeFilter {
  all,
  homeVisit,
  professionalContact,
  phoneCall,
  textNote,
}

extension _EntryTypeFilterLabel on _EntryTypeFilter {
  String get label {
    switch (this) {
      case _EntryTypeFilter.all:
        return 'All entry types';
      case _EntryTypeFilter.homeVisit:
        return EntryType.homeVisit.label;
      case _EntryTypeFilter.professionalContact:
        return EntryType.professionalContact.label;
      case _EntryTypeFilter.phoneCall:
        return EntryType.phoneCall.label;
      case _EntryTypeFilter.textNote:
        return EntryType.textNote.label;
    }
  }

  EntryType? get entryType {
    switch (this) {
      case _EntryTypeFilter.all:
        return null;
      case _EntryTypeFilter.homeVisit:
        return EntryType.homeVisit;
      case _EntryTypeFilter.professionalContact:
        return EntryType.professionalContact;
      case _EntryTypeFilter.phoneCall:
        return EntryType.phoneCall;
      case _EntryTypeFilter.textNote:
        return EntryType.textNote;
    }
  }
}

enum _EntryDateFilter { all, currentFortnight, previousFortnight, last30Days }

extension _EntryDateFilterLabel on _EntryDateFilter {
  String get label {
    switch (this) {
      case _EntryDateFilter.all:
        return 'All dates';
      case _EntryDateFilter.currentFortnight:
        return 'Current fortnight';
      case _EntryDateFilter.previousFortnight:
        return 'Previous fortnight';
      case _EntryDateFilter.last30Days:
        return 'Last 30 days';
    }
  }
}
