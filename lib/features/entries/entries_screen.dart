// ignore_for_file: prefer_collection_literals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/calendar_export_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';
import 'edit_entry_sheet.dart';
import 'local_support_note_button.dart';

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
          showTravel: !appState.isPayeMode,
          onSave: (updatedEntry) {
            final calendarNeedsReentry =
                entry.googleCalendarEntered &&
                updatedEntry.googleCalendarEntered &&
                !entry.hasSameCalendarEventDetails(updatedEntry);

            appState.updateEntry(updatedEntry);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  calendarNeedsReentry
                      ? 'Entry updated. Create the calendar event again.'
                      : 'Entry updated',
                ),
              ),
            );
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
        return currentFortnight(
          anchorDate: context.read<AppState>().settings.payPeriodAnchorDate,
        ).contains(entry.date);
      case _EntryDateFilter.previousFortnight:
        return currentFortnight(
          anchorDate: context.read<AppState>().settings.payPeriodAnchorDate,
        ).previous.contains(entry.date);
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
    final payeMode = appState.isPayeMode;
    final filteredEntries = _filteredEntries(entries);

    final currentRange = currentFortnight(
      anchorDate: settings.payPeriodAnchorDate,
    );
    final currentPeriodEntries = entriesInRange(entries, currentRange);

    final headerWidgets = <Widget>[
      _ClientAnalyticsSection(
        entries: currentPeriodEntries,
        showKilometres: !payeMode,
      ),
      const SizedBox(height: 12),
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
          if (!payeMode)
            StatCard(
              title: 'Earnings',
              value: money(totalEarnings(filteredEntries, settings)),
            ),
          if (!payeMode)
            StatCard(
              title: 'KM',
              value: totalKilometres(filteredEntries).toStringAsFixed(1),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];

    final resultItemCount = filteredEntries.isEmpty
        ? 1
        : (filteredEntries.length * 2) - 1;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: headerWidgets.length + resultItemCount,
      itemBuilder: (context, index) {
        if (index < headerWidgets.length) {
          return headerWidgets[index];
        }

        final resultIndex = index - headerWidgets.length;

        if (filteredEntries.isEmpty) {
          return SectionCard(
            title: 'Results',
            child: EmptyState(
              message: entries.isEmpty
                  ? 'No entries yet. Use Quick Entry or Paste Invoice Rows.'
                  : 'No entries match these filters.',
            ),
          );
        }

        if (resultIndex.isOdd) {
          return const SizedBox(height: 12);
        }

        final entry = filteredEntries[resultIndex ~/ 2];

        return _EntryCard(
          entry: entry,
          onEdit: () => _openEditSheet(context: context, entry: entry),
        );
      },
    );
  }
}

class _ClientAnalyticsSection extends StatelessWidget {
  const _ClientAnalyticsSection({
    required this.entries,
    required this.showKilometres,
  });

  final List<WorkEntry> entries;
  final bool showKilometres;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final summaries = _clientSummaries(entries, settings);

    return SectionCard(
      title: 'Current Fortnight Client Analytics',
      child: summaries.isEmpty
          ? const EmptyState(
              message: 'Client analytics appear after entries are saved.',
            )
          : Column(
              children: [
                for (final summary in summaries)
                  _ClientSummaryTile(
                    summary: summary,
                    showKilometres: showKilometres,
                  ),
              ],
            ),
    );
  }

  List<_ClientSummary> _clientSummaries(
    List<WorkEntry> entries,
    dynamic settings,
  ) {
    final map = <String, _ClientSummary>{};

    for (final entry in entries) {
      final current =
          map[entry.client] ??
          _ClientSummary(
            client: entry.client,
            hours: 0,
            kilometres: 0,
            earnings: 0,
          );

      map[entry.client] = current.copyWith(
        hours: current.hours + entry.hours,
        kilometres: current.kilometres + entry.kilometres,
        earnings: current.earnings + entry.earnings(settings),
      );
    }

    final summaries = map.values.toList()
      ..sort((a, b) => b.earnings.compareTo(a.earnings));

    return summaries;
  }
}

class _ClientSummaryTile extends StatelessWidget {
  const _ClientSummaryTile({
    required this.summary,
    required this.showKilometres,
  });

  final _ClientSummary summary;
  final bool showKilometres;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.client,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Hours',
                  value: summary.hours.toStringAsFixed(2),
                ),
              ),
              if (showKilometres) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniMetric(
                    label: 'KM',
                    value: summary.kilometres.toStringAsFixed(1),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'Earned',
                  value: money(summary.earnings),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientSummary {
  const _ClientSummary({
    required this.client,
    required this.hours,
    required this.kilometres,
    required this.earnings,
  });

  final String client;
  final double hours;
  final double kilometres;
  final double earnings;

  _ClientSummary copyWith({
    double? hours,
    double? kilometres,
    double? earnings,
  }) {
    return _ClientSummary(
      client: client,
      hours: hours ?? this.hours,
      kilometres: kilometres ?? this.kilometres,
      earnings: earnings ?? this.earnings,
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
            isExpanded: true,
            initialValue: typeFilter,
            decoration: const InputDecoration(labelText: 'Entry type'),
            items: [
              for (final filter in _EntryTypeFilter.values)
                DropdownMenuItem<_EntryTypeFilter>(
                  value: filter,
                  child: Text(filter.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onTypeFilterChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_EntryDateFilter>(
            isExpanded: true,
            initialValue: dateFilter,
            decoration: const InputDecoration(labelText: 'Date range'),
            items: [
              for (final filter in _EntryDateFilter.values)
                DropdownMenuItem<_EntryDateFilter>(
                  value: filter,
                  child: Text(filter.label, overflow: TextOverflow.ellipsis),
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

  Future<void> _exportIcs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    try {
      await CalendarExportService.saveIcsFileForEntry(entry);

      messenger.showSnackBar(
        SnackBar(
          content: Text('${entry.client} ICS file exported'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ICS export failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openGoogleCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final appState = context.read<AppState>();

    try {
      await appState.createPrivateGoogleCalendarEvent(entry);

      appState.updateEntry(entry.copyWith(googleCalendarEntered: true));

      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Google Calendar draft opened and marked entered.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              appState.updateEntry(
                entry.copyWith(googleCalendarEntered: false),
              );
            },
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Google Calendar draft failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyEntry(BuildContext context, AppSettings settings) {
    Clipboard.setData(ClipboardData(text: entry.textSummary(settings)));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry copied')));
  }

  void _duplicateEntry(BuildContext context) {
    context.read<AppState>().duplicateEntry(entry);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry duplicated')));
  }

  Future<void> _deleteEntry(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmDeleteEntry(context, entry);

    if (!confirmed) return;

    var deletedDriveFileCount = 0;
    if (appState.isPayeMode) {
      try {
        deletedDriveFileCount = (await appState.deletePayeDriveNoteForEntry(
          entry,
        )).length;
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Entry not deleted. Could not permanently delete PAYE Google Doc: $error',
            ),
          ),
        );
        return;
      }
    }

    final removed = appState.deleteEntry(entry);

    if (removed == null) return;

    if (appState.isPayeMode) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deletedDriveFileCount == 0
                ? 'PAYE entry deleted'
                : 'PAYE entry deleted and $deletedDriveFileCount Google Drive/Docs file(s) permanently deleted',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => appState.restoreEntry(removed),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF151B29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry.client} actions',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.type.label} | ${formatDate(entry.date)} | ${entry.hours.toStringAsFixed(2)}h',
                    style: const TextStyle(color: Color(0xFF8396C7)),
                  ),
                ),
                const SizedBox(height: 8),
                _EntryActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit entry',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onEdit();
                  },
                ),
                _EntryActionTile(
                  icon: Icons.copy_outlined,
                  label: 'Copy summary',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _copyEntry(context, settings);
                  },
                ),
                _EntryActionTile(
                  icon: Icons.copy_all_outlined,
                  label: 'Duplicate entry',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _duplicateEntry(context);
                  },
                ),
                _EntryActionTile(
                  icon: entry.googleCalendarEntered
                      ? Icons.event_available_outlined
                      : Icons.calendar_month_outlined,
                  label: entry.googleCalendarEntered
                      ? 'Calendar entered'
                      : 'Open Calendar draft',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openGoogleCalendar(context);
                  },
                ),
                _EntryActionTile(
                  icon: Icons.event_available_outlined,
                  label: 'Download ICS file',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _exportIcs(context);
                  },
                ),
                const Divider(height: 18),
                _EntryActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete entry',
                  danger: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteEntry(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
              title: Text(
                entry.client,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${entry.type.label} | ${formatDate(entry.date)} | ${entry.baseMinutes} min | ${entry.hours.toStringAsFixed(2)}h',
              ),
              trailing: Text(
                money(entry.earnings(settings)),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (entry.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
            if (entry.googleCalendarEntered) ...[
              const Chip(
                avatar: Icon(Icons.event_available_outlined, size: 18),
                label: Text('Calendar entered'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: 10),
            ],
            if (entry.type.isWrittenContact) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.sms_outlined, size: 18),
                    label: Text(entry.textContactDirection.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: Icon(
                      entry.importantText
                          ? Icons.priority_high_rounded
                          : Icons.label_outline,
                      size: 18,
                      color: entry.importantText
                          ? const Color(0xFFD50000)
                          : const Color(0xFF039BE5),
                    ),
                    label: Text(
                      entry.importantText
                          ? 'Important contact'
                          : 'Normal contact',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: Icon(
                      entry.textReplyNeeded
                          ? Icons.reply_outlined
                          : Icons.check_circle_outline,
                      size: 18,
                      color: entry.textReplyNeeded
                          ? const Color(0xFFFFD166)
                          : const Color(0xFF31E981),
                    ),
                    label: Text(
                      entry.textReplyNeeded
                          ? 'Reply needed'
                          : 'No reply needed',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                LocalSupportNoteButton(entry: entry),
                TextButton.icon(
                  onPressed: () => _deleteEntry(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showActions(context, settings),
                icon: const Icon(Icons.more_horiz),
                label: const Text('Actions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDeleteEntry(BuildContext context, WorkEntry entry) async {
  final payeMode = context.read<AppState>().isPayeMode;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete this note?'),
            content: Text(
              payeMode
                  ? 'Delete ${entry.client} on ${formatDate(entry.date)} from the app? '
                        'Any matching PAYE Google Doc under this Google account will be permanently deleted, not moved to bin.'
                  : 'Delete ${entry.client} on ${formatDate(entry.date)} from the app? '
                        'This syncs the app entry deletion, but does not remove existing Google Drive DOCX files.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          );
        },
      ) ??
      false;
}

class _EntryActionTile extends StatelessWidget {
  const _EntryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      onTap: onTap,
    );
  }
}

enum _EntryTypeFilter {
  all,
  homeVisit,
  professionalContact,
  phoneCall,
  videoCall,
  emailClient,
  emailProfessional,
  adminEducationResources,
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
      case _EntryTypeFilter.videoCall:
        return EntryType.videoCall.label;
      case _EntryTypeFilter.emailClient:
        return EntryType.emailClient.label;
      case _EntryTypeFilter.emailProfessional:
        return EntryType.emailProfessional.label;
      case _EntryTypeFilter.adminEducationResources:
        return EntryType.adminEducationResources.label;
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
      case _EntryTypeFilter.videoCall:
        return EntryType.videoCall;
      case _EntryTypeFilter.emailClient:
        return EntryType.emailClient;
      case _EntryTypeFilter.emailProfessional:
        return EntryType.emailProfessional;
      case _EntryTypeFilter.adminEducationResources:
        return EntryType.adminEducationResources;
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
