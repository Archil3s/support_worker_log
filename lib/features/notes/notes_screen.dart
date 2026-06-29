// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/general_action.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/models/google_drive_file.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/local_support_note_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/note_text_input_tools.dart';
import '../../shared/widgets/notes_storage_gate.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';
import '../../shared/widgets/support_note_breakdown_text.dart';
import '../../shared/widgets/web_spacing.dart';

String _noteTitleForEntry({
  required WorkEntry entry,
  required EntrySupportNoteStatus status,
  String? fallbackName,
}) {
  final person = _personNameForNote(entry, fallback: fallbackName);
  return '$person | ${formatDate(entry.date)} | ${status.label}';
}

String _personNameForNote(WorkEntry entry, {String? fallback}) {
  return LocalSupportNoteService.personNameForEntry(entry, fallback: fallback);
}

String? _bestPersonNameFallback(
  WorkEntry entry,
  EntrySupportNoteMeta? localMeta,
  EntryDriveSupportNoteMeta? driveMeta,
  Iterable<String> candidates,
) {
  final matchedCandidate = _matchingNameCandidate(entry.client, candidates);
  final names = [localMeta?.initials, driveMeta?.initials, matchedCandidate]
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  if (names.isEmpty) return null;

  return names.firstWhere(_looksLikeFullName, orElse: () => names.first);
}

String? _matchingNameCandidate(String initialsCode, Iterable<String> names) {
  final code = initialsCode
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  if (code.isEmpty) return null;

  for (final name in names) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == code.toLowerCase()) {
      continue;
    }
    if (LocalSupportNoteService.defaultInitialsForName(cleaned) == code) {
      return cleaned;
    }
  }

  return null;
}

bool _looksLikeFullName(String name) {
  if (name.contains(RegExp(r'\s'))) return true;

  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (cleaned.length <= 2) return false;

  return LocalSupportNoteService.defaultInitialsForName(name) !=
      cleaned.toUpperCase();
}

bool _shouldAutoSyncGoogleDoc(EntrySupportNoteStatus status) {
  return status == EntrySupportNoteStatus.finished ||
      status == EntrySupportNoteStatus.submitted;
}

String _friendlyErrorText(Object error) {
  final text = error.toString().trim();
  if (text.startsWith('Bad state: ')) {
    return text.replaceFirst('Bad state: ', '');
  }

  return text;
}

String _dateTimeText(BuildContext context, DateTime value) {
  final time = TimeOfDay.fromDateTime(value).format(context);
  return '${formatDate(value)} $time';
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final searchController = TextEditingController();

  String search = '';
  String? clientFilter;
  EntrySupportNoteStatus? statusFilter;
  bool syncingLivingDocs = false;
  bool loadingLivingDocs = false;
  List<LivingSupportDocumentSummary> livingDocs = const [];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<WorkEntry> _filtered(List<WorkEntry> entries) {
    final query = search.trim().toLowerCase();
    final selectedClient = clientFilter;

    final filtered = entries.where((entry) {
      if (selectedClient != null && entry.client != selectedClient) {
        return false;
      }

      if (query.isEmpty) return true;

      return entry.client.toLowerCase().contains(query) ||
          entry.type.label.toLowerCase().contains(query) ||
          formatDate(entry.date).toLowerCase().contains(query);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  Future<void> _chooseFolder() async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    try {
      await LocalSupportNoteService.chooseFolder();

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            r'Default notes folder selected: C:\Users\Danie\MR NOTES FOLDER',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Folder selection failed: ${_friendlyErrorText(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _syncLivingDocuments() async {
    if (syncingLivingDocs) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    setState(() => syncingLivingDocs = true);

    try {
      final results = await context
          .read<AppState>()
          .syncLivingSupportDocumentsFromEntries();
      final imported = results.fold<int>(
        0,
        (total, result) => total + result.importedCount,
      );
      final updated = results.fold<int>(
        0,
        (total, result) => total + result.updatedCount,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${results.length} living docs. Imported $imported, updated $updated.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Living Google Docs sync failed: ${_friendlyErrorText(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => syncingLivingDocs = false);
    }
  }

  Future<void> _loadLivingDocuments() async {
    if (loadingLivingDocs) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    setState(() => loadingLivingDocs = true);

    try {
      final results = await context
          .read<AppState>()
          .loadLivingSupportDocuments();
      if (!mounted) return;

      setState(() => livingDocs = results);
      messenger.showSnackBar(
        SnackBar(content: Text('Loaded ${results.length} living docs.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Living Google Docs load failed: ${_friendlyErrorText(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loadingLivingDocs = false);
    }
  }

  Future<void> _openLivingDocument(
    LivingSupportDocumentSummary document,
  ) async {
    final link = document.openLink;
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Living Google Doc link is missing.')),
        );
      return;
    }

    await _launchDriveLink(Uri.parse(link));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allEntries = appState.entries;
    final clients = {
      ...appState.clients,
      ...allEntries.map((entry) => entry.client),
    }.where((client) => client.trim().isNotEmpty).toList()..sort();
    final entries = _filtered(allEntries);
    return NotesStorageGate(
      child: _NotesListTab(
        entries: entries,
        statusFilter: statusFilter,
        searchController: searchController,
        search: search,
        clients: clients,
        clientFilter: clientFilter,
        onSearchChanged: (value) => setState(() => search = value),
        onClearSearch: () {
          setState(() {
            searchController.clear();
            search = '';
          });
        },
        onClientFilterChanged: (value) {
          setState(() => clientFilter = value);
        },
        onStatusFilterChanged: (value) {
          setState(() => statusFilter = value);
        },
        onChooseFolder: _chooseFolder,
        onSyncLivingDocuments: _syncLivingDocuments,
        onLoadLivingDocuments: _loadLivingDocuments,
        onOpenLivingDocument: _openLivingDocument,
        syncingLivingDocs: syncingLivingDocs,
        loadingLivingDocs: loadingLivingDocs,
        livingDocs: livingDocs,
      ),
    );
  }
}

class _NotesListTab extends StatelessWidget {
  const _NotesListTab({
    required this.entries,
    required this.statusFilter,
    required this.searchController,
    required this.search,
    required this.clients,
    required this.clientFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onClientFilterChanged,
    required this.onStatusFilterChanged,
    required this.onChooseFolder,
    required this.onSyncLivingDocuments,
    required this.onLoadLivingDocuments,
    required this.onOpenLivingDocument,
    required this.syncingLivingDocs,
    required this.loadingLivingDocs,
    required this.livingDocs,
  });

  final List<WorkEntry> entries;
  final EntrySupportNoteStatus? statusFilter;
  final TextEditingController searchController;
  final String search;
  final List<String> clients;
  final String? clientFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onClientFilterChanged;
  final ValueChanged<EntrySupportNoteStatus?> onStatusFilterChanged;
  final VoidCallback onChooseFolder;
  final VoidCallback onSyncLivingDocuments;
  final VoidCallback onLoadLivingDocuments;
  final ValueChanged<LivingSupportDocumentSummary> onOpenLivingDocument;
  final bool syncingLivingDocs;
  final bool loadingLivingDocs;
  final List<LivingSupportDocumentSummary> livingDocs;

  @override
  Widget build(BuildContext context) {
    final payeMode = context.watch<AppState>().isPayeMode;

    return ListView(
      padding: webPagePadding(context),
      children: [
        _NotesOverview(entries: entries),
        const SizedBox(height: 12),
        SectionCard(
          title: payeMode ? 'PAYE Notes' : 'Local Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onChooseFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(
                  payeMode
                      ? 'Use Default PAYE Notes Folder'
                      : 'Use Default MR NOTES FOLDER',
                ),
              ),
              if (!payeMode) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: syncingLivingDocs ? null : onSyncLivingDocuments,
                  icon: syncingLivingDocs
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_outlined),
                  label: Text(
                    syncingLivingDocs
                        ? 'Syncing Living Google Docs'
                        : 'Sync Living Google Docs',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: loadingLivingDocs ? null : onLoadLivingDocuments,
                  icon: loadingLivingDocs
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tab_outlined),
                  label: Text(
                    loadingLivingDocs
                        ? 'Loading Living Google Docs'
                        : 'Load Living Google Docs',
                  ),
                ),
                if (livingDocs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final document in livingDocs) ...[
                    _LivingDocumentTile(
                      document: document,
                      onOpen: () => onOpenLivingDocument(document),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
              const SizedBox(height: 10),
              Text(
                payeMode
                    ? 'Create, test, save, open, and remove PAYE Google Docs notes from saved PAYE entries.'
                    : 'Create and sync Google Docs notes attached to saved entries.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Find Notes',
          child: Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Search notes',
                  helperText: 'Search by person, date, or support type',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: search.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: clientFilter,
                decoration: const InputDecoration(labelText: 'Client filter'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All clients'),
                  ),
                  for (final client in clients)
                    DropdownMenuItem<String?>(
                      value: client,
                      child: Text(client, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onClientFilterChanged,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EntrySupportNoteStatus?>(
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: 'Status filter'),
                items: [
                  const DropdownMenuItem<EntrySupportNoteStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final item in EntrySupportNoteStatus.values)
                    DropdownMenuItem<EntrySupportNoteStatus?>(
                      value: item,
                      child: Text(item.label),
                    ),
                ],
                onChanged: onStatusFilterChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const SectionCard(
            title: 'Notes',
            child: EmptyState(message: 'No entries available for notes yet.'),
          )
        else
          for (final entry in entries) ...[
            _NoteEntryCard(entry: entry, statusFilter: statusFilter),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LivingDocumentTile extends StatelessWidget {
  const _LivingDocumentTile({required this.document, required this.onOpen});

  final LivingSupportDocumentSummary document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF26385F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    document.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesOverview extends StatelessWidget {
  const _NotesOverview({required this.entries});

  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayEntries = entries.where((entry) {
      return entry.date.year == today.year &&
          entry.date.month == today.month &&
          entry.date.day == today.day;
    }).length;
    final missingNotes = entries
        .where((entry) => entry.supportNoteBreakdown.trim().isEmpty)
        .length;
    final openActions = entries.fold<int>(
      0,
      (count, entry) =>
          count + entry.nextActions.where((item) => !item.isCompleted).length,
    );
    final calendarGaps = entries
        .where((entry) => !entry.googleCalendarEntered)
        .length;

    return SectionCard(
      title: 'Notes Overview',
      child: StatGrid(
        cards: [
          StatCard(title: 'Today', value: '$todayEntries'),
          StatCard(title: 'Missing', value: '$missingNotes'),
          StatCard(title: 'Actions', value: '$openActions'),
          StatCard(title: 'Calendar', value: '$calendarGaps'),
        ],
      ),
    );
  }
}

class _NextActionsTab extends StatelessWidget {
  const _NextActionsTab({required this.entries});

  final List<WorkEntry> entries;

  List<_EntryAction> get _openActions {
    final actions = <_EntryAction>[];

    for (final entry in entries) {
      for (final action in entry.nextActions) {
        if (!action.isCompleted) {
          actions.add(_EntryAction(entry: entry, action: action));
        }
      }
    }

    return actions;
  }

  List<_EntryAction> get _completedActions {
    return const [];
  }

  void _deleteAction({
    required BuildContext context,
    required WorkEntry entry,
    required NextActionItem action,
  }) {
    context.read<AppState>().deleteNextAction(entry: entry, action: action);
  }

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;
    final completedActions = _completedActions;

    return ListView(
      padding: webPagePadding(context),
      children: [
        SectionCard(
          title: 'Next Actions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${openActions.length} open | ${completedActions.length} completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Actions come from the Next action(s) section when you finish a visit. Ticking or deleting an action removes it from the saved entry.',
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (openActions.isEmpty && completedActions.isEmpty)
          const SectionCard(
            title: 'No Actions',
            child: EmptyState(
              message:
                  'No next actions yet. Add them in the breakdown when you finish a visit.',
            ),
          )
        else ...[
          SectionCard(
            title: 'Open',
            child: openActions.isEmpty
                ? const EmptyState(message: 'No open actions.')
                : Column(
                    children: [
                      for (final item in openActions)
                        _NextActionTile(
                          entry: item.entry,
                          action: item.action,
                          onChanged: (_) => _deleteAction(
                            context: context,
                            entry: item.entry,
                            action: item.action,
                          ),
                          onDelete: () => _deleteAction(
                            context: context,
                            entry: item.entry,
                            action: item.action,
                          ),
                        ),
                    ],
                  ),
          ),
          if (completedActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Completed Log',
              child: Column(
                children: [
                  for (final item in completedActions)
                    _NextActionTile(
                      entry: item.entry,
                      action: item.action,
                      onChanged: (_) => _deleteAction(
                        context: context,
                        entry: item.entry,
                        action: item.action,
                      ),
                      onDelete: () => _deleteAction(
                        context: context,
                        entry: item.entry,
                        action: item.action,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _EntryAction {
  const _EntryAction({required this.entry, required this.action});

  final WorkEntry entry;
  final NextActionItem action;
}

class _NextActionTile extends StatelessWidget {
  const _NextActionTile({
    required this.entry,
    required this.action,
    required this.onChanged,
    required this.onDelete,
  });

  final WorkEntry entry;
  final NextActionItem action;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  Future<void> _openNote(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryNoteSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: action.isCompleted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF31E981),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Open note',
              onPressed: () => _openNote(context),
              icon: const Icon(Icons.note_alt_outlined),
            ),
            IconButton(
              tooltip: 'Delete action',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        title: Text(
          action.text,
          style: TextStyle(
            decoration: action.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text('${entry.client} | ${formatDate(entry.date)}'),
      ),
    );
  }
}

class _GeneralActionsTab extends StatefulWidget {
  const _GeneralActionsTab({required this.clients, required this.actions});

  final List<String> clients;
  final List<GeneralActionItem> actions;

  @override
  State<_GeneralActionsTab> createState() => _GeneralActionsTabState();
}

class _GeneralActionsTabState extends State<_GeneralActionsTab> {
  final actionController = TextEditingController();

  GeneralActionScope scope = GeneralActionScope.client;
  String? selectedClient;

  @override
  void initState() {
    super.initState();
    selectedClient = widget.clients.isEmpty ? null : widget.clients.first;
  }

  @override
  void didUpdateWidget(covariant _GeneralActionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (selectedClient != null && widget.clients.contains(selectedClient)) {
      return;
    }

    selectedClient = widget.clients.isEmpty ? null : widget.clients.first;
  }

  @override
  void dispose() {
    actionController.dispose();
    super.dispose();
  }

  List<GeneralActionItem> get _openActions {
    return widget.actions.where((action) => !action.isCompleted).toList();
  }

  List<GeneralActionItem> get _completedActions {
    return widget.actions.where((action) => action.isCompleted).toList();
  }

  void _addAction() {
    final title = actionController.text.trim();
    if (title.isEmpty) return;

    final client = scope == GeneralActionScope.client
        ? selectedClient ??
              (widget.clients.isEmpty ? null : widget.clients.first)
        : null;

    if (scope == GeneralActionScope.client &&
        (client == null || client.trim().isEmpty)) {
      return;
    }

    context.read<AppState>().addGeneralAction(
      GeneralActionItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        scope: scope,
        client: client,
        createdAt: DateTime.now(),
      ),
    );

    actionController.clear();
  }

  void _toggleAction(GeneralActionItem action, bool completed) {
    context.read<AppState>().updateGeneralAction(
      action.copyWith(
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      ),
    );
  }

  void _deleteAction(GeneralActionItem action) {
    context.read<AppState>().deleteGeneralAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;
    final completedActions = _completedActions;
    final clientActions = openActions
        .where((action) => action.scope == GeneralActionScope.client)
        .toList();
    final knowledgeActions = openActions
        .where((action) => action.scope == GeneralActionScope.knowledgeGap)
        .toList();

    return ListView(
      padding: webPagePadding(context),
      children: [
        SectionCard(
          title: 'Add Mixed Action',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<GeneralActionScope>(
                segments: const [
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.client,
                    icon: Icon(Icons.person_outline),
                    label: Text('Client'),
                  ),
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.knowledgeGap,
                    icon: Icon(Icons.school_outlined),
                    label: Text('Knowledge'),
                  ),
                ],
                selected: {scope},
                onSelectionChanged: (values) {
                  setState(() => scope = values.first);
                },
              ),
              if (scope == GeneralActionScope.client) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedClient,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: [
                    for (final client in widget.clients)
                      DropdownMenuItem<String>(
                        value: client,
                        child: Text(client, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => selectedClient = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: actionController,
                minLines: 3,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: scope == GeneralActionScope.client
                      ? 'Client action'
                      : 'Knowledge gap / thing to look into',
                  hintText: scope == GeneralActionScope.client
                      ? 'What needs doing for this client?'
                      : 'What do you need to research or clarify?',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.add_task_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addAction,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Action'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'Client Actions',
          emptyMessage: 'No open client actions.',
          actions: clientActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'Knowledge Gaps',
          emptyMessage: 'No open knowledge gaps.',
          actions: knowledgeActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        if (completedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GeneralActionSection(
            title: 'Completed Mixed Actions',
            emptyMessage: 'No completed mixed actions.',
            actions: completedActions,
            onChanged: _toggleAction,
            onDelete: _deleteAction,
          ),
        ],
      ],
    );
  }
}

class _GeneralActionSection extends StatelessWidget {
  const _GeneralActionSection({
    required this.title,
    required this.emptyMessage,
    required this.actions,
    required this.onChanged,
    required this.onDelete,
  });

  final String title;
  final String emptyMessage;
  final List<GeneralActionItem> actions;
  final void Function(GeneralActionItem action, bool completed) onChanged;
  final ValueChanged<GeneralActionItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: actions.isEmpty
          ? EmptyState(message: emptyMessage)
          : Column(
              children: [
                for (final action in actions)
                  _GeneralActionTile(
                    action: action,
                    onChanged: (completed) => onChanged(action, completed),
                    onDelete: () => onDelete(action),
                  ),
              ],
            ),
    );
  }
}

class _GeneralActionTile extends StatelessWidget {
  const _GeneralActionTile({
    required this.action,
    required this.onChanged,
    required this.onDelete,
  });

  final GeneralActionItem action;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completedAt = action.completedAt;
    final subtitle = action.scope == GeneralActionScope.client
        ? action.client ?? 'Client action'
        : 'Knowledge gap';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: action.isCompleted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF31E981),
        secondary: IconButton(
          tooltip: 'Delete action',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        title: Text(
          action.title,
          style: TextStyle(
            decoration: action.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          completedAt == null
              ? subtitle
              : '$subtitle | completed ${_dateTimeText(context, completedAt)}',
        ),
      ),
    );
  }
}

class _NoteEntryCard extends StatefulWidget {
  const _NoteEntryCard({required this.entry, required this.statusFilter});

  final WorkEntry entry;
  final EntrySupportNoteStatus? statusFilter;

  @override
  State<_NoteEntryCard> createState() => _NoteEntryCardState();
}

class _NoteEntryCardState extends State<_NoteEntryCard> {
  final GoogleDriveService driveService = GoogleDriveService();

  EntrySupportNoteMeta? meta;
  EntryDriveSupportNoteMeta? driveMeta;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _NoteEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.id != widget.entry.id) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final googleAccountEmail = _currentGoogleAccountEmail(appState);
    final localMeta = await LocalSupportNoteService.loadMeta(widget.entry.id);
    var loaded = _preferredEntrySupportNoteMeta(
      localMeta,
      appState.supportNoteMetaFor(widget.entry.id),
    );
    final savedDrive = _driveMetaForAccount(
      await driveService.loadSupportNoteMeta(widget.entry.id),
      googleAccountEmail,
    );
    final syncedDrive = _driveMetaForAccount(
      appState.driveSupportNoteMetaFor(widget.entry.id),
      googleAccountEmail,
    );
    var loadedDrive =
        _preferredDriveSupportNoteMeta(savedDrive, syncedDrive) ??
        await appState.findEntryNoteInCurrentDrive(widget.entry);
    if (loadedDrive != null) {
      try {
        loadedDrive = await appState.syncEntryNoteFromGoogleDoc(
          entry: widget.entry,
          existingMeta: loadedDrive,
          payeMode: appState.isPayeMode,
        );
        loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);
      } catch (_) {
        // The visible sync button reports connection or permission errors.
      }
    }

    if (loaded != null) {
      appState.upsertSupportNoteMeta(loaded);
    }

    if (loadedDrive != null) {
      appState.upsertDriveSupportNoteMeta(loadedDrive);
    }

    if (!mounted) return;

    setState(() {
      meta = loaded;
      driveMeta = loadedDrive;
    });
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryNoteSheet(entry: widget.entry),
    );

    await _load();
  }

  Future<void> _openLocalFile() async {
    final current = meta;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    if (current == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Create the local note file first.')),
      );
      return;
    }

    try {
      await LocalSupportNoteService.openNote(current);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open local note: $error')),
      );
    }
  }

  Future<void> _openDriveFile() async {
    final link = driveMeta?.openLink;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    if (link == null || link.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Create the Google Doc first.')),
      );
      return;
    }

    await launchUrl(Uri.parse(link), webOnlyWindowName: '_blank');
  }

  Future<void> _deleteEntry() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmDeleteEntry(
      context,
      widget.entry,
      displayName: _personNameForNote(
        widget.entry,
        fallback: _bestPersonNameFallback(
          widget.entry,
          meta,
          driveMeta,
          appState.clients,
        ),
      ),
    );

    if (!confirmed) return;

    var deletedDriveFileCount = 0;
    if (appState.isPayeMode) {
      try {
        deletedDriveFileCount = (await appState.deletePayeDriveNoteForEntry(
          widget.entry,
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
    } else {
      await appState.deleteStoredSupportNoteData(widget.entry.id);
    }

    final removed = appState.deleteEntry(widget.entry);

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

    messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.statusFilter;

    final status = _preferredStatus(meta?.status, driveMeta?.status);

    if (filter != null && status != filter) {
      return const SizedBox.shrink();
    }

    final hasLocal = meta?.fileName.isNotEmpty == true;
    final hasDriveNote = driveMeta?.openLink?.isNotEmpty == true;
    final appState = context.watch<AppState>();
    final fallbackName = _bestPersonNameFallback(
      widget.entry,
      meta,
      driveMeta,
      appState.clients,
    );
    final displayName = _personNameForNote(
      widget.entry,
      fallback: fallbackName,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _statusColor(status).withValues(alpha: 0.18),
                child: Icon(
                  Icons.note_alt_outlined,
                  color: _statusColor(status),
                ),
              ),
              title: Text(
                _noteTitleForEntry(
                  entry: widget.entry,
                  status: status,
                  fallbackName: fallbackName,
                ),
              ),
              subtitle: Text(
                '$displayName | ${widget.entry.type.label} | ${widget.entry.baseMinutes} min | ${widget.entry.hours.toStringAsFixed(2)}h',
              ),
              trailing: _StatusPill(status: status),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NoteFileChip(
                  icon: Icons.folder_outlined,
                  label: hasLocal ? 'Local file' : 'No local file',
                  ready: hasLocal,
                  onPressed: hasLocal ? _openLocalFile : null,
                ),
                _NoteFileChip(
                  icon: Icons.cloud_done_outlined,
                  label: hasDriveNote ? 'Google Drive' : 'No Drive file',
                  ready: hasDriveNote,
                  onPressed: hasDriveNote ? _openDriveFile : null,
                ),
              ],
            ),
            if (hasLocal || driveMeta?.fileName.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              SelectableText(
                [
                  if (hasLocal) 'Local: ${meta!.fileName}',
                  if (driveMeta?.fileName.isNotEmpty == true)
                    'Google Drive: ${driveMeta!.fileName}',
                ].join('\n'),
                style: const TextStyle(
                  color: Color(0xFF8396C7),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (widget.entry.supportNoteBreakdown.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SupportNoteBreakdownText(
                text: widget.entry.supportNoteBreakdown.trim(),
              ),
            ],
            if (widget.entry.nextActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Tracked next actions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final action in widget.entry.nextActions)
                Text(
                  action.completedAt == null
                      ? '- ${action.text}'
                      : '- ${action.text} (completed ${_dateTimeText(context, action.completedAt!)})',
                  style: const TextStyle(height: 1.35),
                ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _openSheet,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(
                    meta == null && driveMeta == null
                        ? 'Create Note'
                        : 'Open Note',
                  ),
                ),
                TextButton.icon(
                  onPressed: _deleteEntry,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteFileChip extends StatelessWidget {
  const _NoteFileChip({
    required this.icon,
    required this.label,
    required this.ready,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool ready;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF31E981) : const Color(0xFF8396C7);

    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w900),
      onPressed: onPressed,
    );
  }
}

class EntryNoteSheet extends StatefulWidget {
  const EntryNoteSheet({super.key, required this.entry});

  final WorkEntry entry;

  @override
  State<EntryNoteSheet> createState() => _EntryNoteSheetState();
}

class _EntryNoteSheetState extends State<EntryNoteSheet> {
  final GoogleDriveService driveService = GoogleDriveService();
  final initialsController = TextEditingController();
  final noteController = TextEditingController();
  final noteFocusNode = FocusNode();

  EntrySupportNoteStatus status = EntrySupportNoteStatus.incomplete;
  EntrySupportNoteMeta? meta;
  EntryDriveSupportNoteMeta? driveMeta;
  bool busy = false;
  bool autoSaving = false;
  bool suppressAutoSave = false;
  Timer? autoSaveDebounce;
  Timer? googleDocSyncTimer;
  int autoSaveVersion = 0;
  String? message;

  @override
  void initState() {
    super.initState();
    initialsController.addListener(_onAttachedNoteChanged);
    noteController.addListener(_onAttachedNoteChanged);
    unawaited(_load());
    _startGoogleDocSyncTimer();
  }

  @override
  void dispose() {
    autoSaveDebounce?.cancel();
    googleDocSyncTimer?.cancel();
    initialsController.removeListener(_onAttachedNoteChanged);
    noteController.removeListener(_onAttachedNoteChanged);
    initialsController.dispose();
    noteController.dispose();
    noteFocusNode.dispose();
    super.dispose();
  }

  void _startGoogleDocSyncTimer() {
    googleDocSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || busy || autoSaving || driveMeta == null) return;
      unawaited(_syncFromGoogleDoc(silent: true));
    });
  }

  void _onAttachedNoteChanged() {
    if (suppressAutoSave || (meta == null && driveMeta == null)) return;

    autoSaveDebounce?.cancel();
    autoSaveDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_autoSaveAttachedFiles());
    });
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final googleAccountEmail = _currentGoogleAccountEmail(appState);
    final localMeta = await LocalSupportNoteService.loadMeta(widget.entry.id);
    var loaded = _preferredEntrySupportNoteMeta(
      localMeta,
      appState.supportNoteMetaFor(widget.entry.id),
    );
    final savedDrive = _driveMetaForAccount(
      await driveService.loadSupportNoteMeta(widget.entry.id),
      googleAccountEmail,
    );
    final syncedDrive = _driveMetaForAccount(
      appState.driveSupportNoteMetaFor(widget.entry.id),
      googleAccountEmail,
    );
    var loadedDrive =
        _preferredDriveSupportNoteMeta(savedDrive, syncedDrive) ??
        await appState.findEntryNoteInCurrentDrive(widget.entry);

    if (loadedDrive != null) {
      try {
        loadedDrive = await appState.syncEntryNoteFromGoogleDoc(
          entry: widget.entry,
          existingMeta: loadedDrive,
          payeMode: appState.isPayeMode,
        );
        loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);
      } catch (_) {
        // The visible sync button reports connection or permission errors.
      }
    }

    if (loaded != null) {
      appState.upsertSupportNoteMeta(loaded);
    }

    if (loadedDrive != null) {
      appState.upsertDriveSupportNoteMeta(loadedDrive);
    }

    if (!mounted) return;

    suppressAutoSave = true;

    setState(() {
      meta = loaded;
      driveMeta = loadedDrive;

      if (loaded == null && loadedDrive != null) {
        initialsController.text = _personNameForNote(
          widget.entry,
          fallback: _bestPersonNameFallback(
            widget.entry,
            null,
            loadedDrive,
            appState.clients,
          ),
        );
        noteController.text = loadedDrive.noteText.trim().isNotEmpty
            ? loadedDrive.noteText
            : _defaultNoteText(
                appState: appState,
                entry: widget.entry,
                status: loadedDrive.status,
              );
        status = loadedDrive.status;
      } else if (loaded == null) {
        initialsController.text = _personNameForNote(
          widget.entry,
          fallback: _bestPersonNameFallback(
            widget.entry,
            null,
            null,
            appState.clients,
          ),
        );
        noteController.text = _defaultNoteText(
          appState: appState,
          entry: widget.entry,
          status: status,
        );
      } else {
        initialsController.text = _personNameForNote(
          widget.entry,
          fallback: _bestPersonNameFallback(
            widget.entry,
            loaded,
            loadedDrive,
            appState.clients,
          ),
        );
        noteController.text = loaded.noteText;
        status = _preferredStatus(loaded.status, loadedDrive?.status);
      }
    });

    suppressAutoSave = false;
  }

  Future<void> _chooseFolder() async {
    setState(() {
      busy = true;
      message = 'Choose C:\\Users\\Danie\\MR NOTES FOLDER in Chrome.';
    });

    try {
      await LocalSupportNoteService.chooseFolder();

      if (!mounted) return;

      setState(() {
        message = 'Folder selected. Now save the note.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Folder selection failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      message = 'Saving local note...';
    });

    try {
      final appState = context.read<AppState>();
      final updated = appState.isPayeMode
          ? await LocalSupportNoteService.savePayeNote(
              entry: widget.entry,
              initials: initialsController.text,
              status: status,
              noteText: noteController.text,
            )
          : await LocalSupportNoteService.saveNote(
              entry: widget.entry,
              initials: initialsController.text,
              status: status,
              noteText: noteController.text,
            );

      if (!mounted) return;

      setState(() {
        meta = updated;
        message = 'Saved locally as ${updated.fileName}';
      });
      appState.upsertSupportNoteMeta(updated);
      _updatePayeEntry(appState);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not save local note: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _saveDraftOnly(
    String nextMessage, {
    bool showMessage = true,
  }) async {
    final appState = context.read<AppState>();
    final noteText = appState.isPayeMode
        ? noteController.text
        : LocalSupportNoteService.canonicalSupportNoteText(noteController.text);
    final updated = await LocalSupportNoteService.saveDraftMeta(
      entry: widget.entry,
      initials: initialsController.text,
      status: status,
      noteText: noteText,
    );

    if (!mounted) return;

    setState(() {
      if (!appState.isPayeMode) noteController.text = noteText;
      meta = updated;
      if (showMessage) message = nextMessage;
    });
    appState.upsertSupportNoteMeta(updated);
    _updatePayeEntry(appState);
  }

  void _updatePayeEntry(AppState appState) {
    if (!appState.isPayeMode) return;

    appState.updatePayeEntry(_payeEntryWithCurrentNote(trimNote: true));
  }

  WorkEntry _payeEntryWithCurrentNote({bool trimNote = false}) {
    return widget.entry.copyWith(
      client: _personNameForNote(
        widget.entry,
        fallback: initialsController.text,
      ),
      supportNoteBreakdown: trimNote
          ? noteController.text.trim()
          : noteController.text,
    );
  }

  Future<void> _saveDraftAndReturn() async {
    setState(() {
      busy = true;
      message = 'Saving note draft...';
    });

    try {
      await _saveDraftOnly('Draft saved in the app.');

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not save note draft: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<String> _clientNotesFolderId(
    AppState appState,
    String accessToken,
  ) async {
    final existing = appState.settings.googleDriveClientNotesFolderId;

    if (existing != null && existing.isNotEmpty) return existing;

    final setup = await driveService.createFolderSetup(
      accessToken: accessToken,
    );
    appState.updateSettings(setup.applyTo(appState.settings));

    return setup.clientNotesFolder.id;
  }

  Future<void> _saveToDrive() async {
    setState(() {
      busy = true;
      message = 'Saving note to Google Drive...';
    });

    try {
      final appState = context.read<AppState>();
      if (appState.isPayeMode) {
        await _saveDraftOnly('Note saved in the app.', showMessage: false);
        final updatedEntry = _payeEntryWithCurrentNote();
        appState.updatePayeEntry(updatedEntry);
        final file = await appState.savePayeNoteToDrive(updatedEntry);
        final discovered = await appState.findEntryNoteInCurrentDrive(
          updatedEntry,
        );
        final updated =
            discovered?.copyWith(
              initials: _personNameForNote(
                widget.entry,
                fallback: initialsController.text,
              ),
              status: status,
              fileId: file.id,
              fileName: file.name,
              noteText: noteController.text,
              mimeType: file.mimeType,
              webViewLink: file.webViewLink,
              googleAccountEmail: appState.payeGoogleAccountEmail,
            ) ??
            EntryDriveSupportNoteMeta(
              entryId: widget.entry.id,
              initials: _personNameForNote(
                widget.entry,
                fallback: initialsController.text,
              ),
              status: status,
              fileId: file.id,
              fileName: file.name,
              noteText: noteController.text,
              mimeType: file.mimeType,
              parentFolderId: driveMeta?.parentFolderId,
              webViewLink: file.webViewLink,
              contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
              googleAccountEmail: appState.payeGoogleAccountEmail,
            );
        await driveService.saveSupportNoteMeta(updated);
        appState.upsertDriveSupportNoteMeta(updated);

        if (!mounted) return;

        setState(() {
          driveMeta = updated;
          message = 'Saved to Google Docs as ${updated.fileName}';
        });
        return;
      }

      final token = await appState.connectGoogleDrive();
      final folderId = await _clientNotesFolderId(appState, token);
      final googleAccountEmail = appState.workGoogleAccountEmail;
      final updated = await driveService.saveSupportNote(
        accessToken: token,
        clientNotesFolderId: folderId,
        entry: widget.entry,
        initials: initialsController.text,
        status: status,
        noteText: LocalSupportNoteService.canonicalSupportNoteText(
          noteController.text,
        ),
        payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
        existingMeta: _driveMetaForAccount(driveMeta, googleAccountEmail),
        googleAccountEmail: googleAccountEmail,
      );

      if (!mounted) return;

      setState(() {
        noteController.text = updated.noteText;
        driveMeta = updated;
        message =
            updated.mimeType == EntryDriveSupportNoteMeta.googleDocsMimeType
            ? 'Saved to Google Docs as ${updated.fileName}'
            : 'Saved to Google Drive as ${updated.fileName}';
      });
      appState.upsertDriveSupportNoteMeta(updated);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not save to Google Drive: ${_friendlyError(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _writeInGoogleDoc() async {
    setState(() {
      busy = true;
      message = driveMeta == null
          ? 'Creating live Google Doc...'
          : 'Opening live Google Doc...';
    });

    try {
      final appState = context.read<AppState>();
      final accountEmail = _currentGoogleAccountEmail(appState);
      final accountMeta = _driveMetaForAccount(driveMeta, accountEmail);
      final accountLink = accountMeta?.openLink;

      if (accountLink != null && accountLink.isNotEmpty) {
        await _launchDriveLink(Uri.parse(accountLink));

        if (!mounted) return;

        setState(() {
          message = 'Opened the live Google Doc.';
        });
        return;
      }

      late EntryDriveSupportNoteMeta updated;

      if (appState.isPayeMode) {
        try {
          await appState.requireGoogleDriveAccessToken(
            scope: GoogleExportAccountScope.paye,
          );
        } catch (_) {
          await appState.connectPayeGoogle();
        }

        final updatedEntry = widget.entry.copyWith(
          supportNoteBreakdown: noteController.text,
        );
        final existing = await appState.findEntryNoteInCurrentDrive(
          updatedEntry,
        );

        if (existing != null &&
            driveService.isGoogleDocsSupportNote(existing)) {
          updated = existing.copyWith(
            initials: initialsController.text.trim().toUpperCase(),
            status: status,
            noteText: noteController.text,
            googleAccountEmail: appState.payeGoogleAccountEmail,
          );
        } else {
          final file = await appState.savePayeNoteToDrive(updatedEntry);
          final discovered = await appState.findEntryNoteInCurrentDrive(
            updatedEntry,
          );
          updated =
              discovered?.copyWith(
                initials: initialsController.text.trim().toUpperCase(),
                status: status,
                fileId: file.id,
                fileName: file.name,
                noteText: noteController.text,
                mimeType: file.mimeType,
                webViewLink: file.webViewLink,
                googleAccountEmail: appState.payeGoogleAccountEmail,
              ) ??
              EntryDriveSupportNoteMeta(
                entryId: widget.entry.id,
                initials: initialsController.text.trim().toUpperCase(),
                status: status,
                fileId: file.id,
                fileName: file.name,
                noteText: noteController.text,
                mimeType: file.mimeType,
                parentFolderId: driveMeta?.parentFolderId,
                webViewLink: file.webViewLink,
                contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
                googleAccountEmail: appState.payeGoogleAccountEmail,
              );
        }
      } else {
        final token = await appState.connectGoogleDrive();
        final folderId = await _clientNotesFolderId(appState, token);
        final existing = await driveService.findSupportNoteInDrive(
          accessToken: token,
          clientNotesFolderId: folderId,
          entry: widget.entry,
          payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
          googleAccountEmail: appState.workGoogleAccountEmail,
        );

        if (existing != null &&
            driveService.isGoogleDocsSupportNote(existing)) {
          final noteText = LocalSupportNoteService.canonicalSupportNoteText(
            noteController.text,
          );
          updated = existing.copyWith(
            initials: initialsController.text.trim().toUpperCase(),
            status: status,
            noteText: noteText,
            googleAccountEmail: appState.workGoogleAccountEmail,
          );
        } else {
          final noteText = LocalSupportNoteService.canonicalSupportNoteText(
            noteController.text,
          );
          updated = await driveService.saveSupportNote(
            accessToken: token,
            clientNotesFolderId: folderId,
            entry: widget.entry,
            initials: initialsController.text,
            status: status,
            noteText: noteText,
            payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
            existingMeta: existing,
            googleAccountEmail: appState.workGoogleAccountEmail,
          );
        }
      }

      await driveService.saveSupportNoteMeta(updated);

      if (!mounted) return;

      setState(() {
        driveMeta = updated;
        message = 'Opened the live Google Doc.';
      });

      final link = updated.openLink;
      if (link == null || link.isEmpty) {
        setState(() {
          message = 'Google Doc was linked, but no open link was returned.';
        });
        return;
      }

      await _launchDriveLink(Uri.parse(link));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not open live Google Doc: ${_friendlyError(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _testGoogleDocsSave() async {
    setState(() {
      busy = true;
      message = 'Creating temporary Google Doc test...';
    });

    try {
      final appState = context.read<AppState>();
      await _saveDraftOnly('Note saved in the app.', showMessage: false);
      final updatedEntry = _payeEntryWithCurrentNote();
      appState.updatePayeEntry(updatedEntry);

      final file = await appState.saveTemporaryPayeNoteToDrive(updatedEntry);
      final link = _googleDocsLink(file);

      if (!mounted) return;

      setState(() {
        message =
            'Temporary Google Doc opened. It will be removed from Drive in 45 seconds.';
      });
      unawaited(_deleteTemporaryGoogleDoc(appState, file));
      await _launchDriveLink(Uri.parse(link));
    } catch (error) {
      if (!mounted) return;

      await _saveDraftOnly(
        'Google Docs test failed: $error\nNote draft is still saved in the app.',
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _deleteTemporaryGoogleDoc(
    AppState appState,
    GoogleDriveFile file,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 45));

    try {
      await appState.deletePayeDriveFile(file.id);
      if (!mounted) return;

      setState(() {
        message = 'Temporary Google Docs test file permanently deleted.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message =
            'Temporary Google Doc opened, but could not be deleted: $error';
      });
    }
  }

  Future<void> _changeStatus(EntrySupportNoteStatus next) async {
    if (status == next) return;

    setState(() {
      status = next;
    });

    if (meta == null && driveMeta == null) {
      suppressAutoSave = true;
      final appState = context.read<AppState>();
      noteController.text = appState.isPayeMode
          ? LocalSupportNoteService.defaultPayeNoteTextForEntry(widget.entry)
          : LocalSupportNoteService.defaultNoteTextForEntry(
              entry: widget.entry,
              status: next,
            );
      suppressAutoSave = false;
      await _saveDraftOnly('Draft status saved.', showMessage: false);
      if (_shouldAutoSyncGoogleDoc(next)) {
        await _autoSaveAttachedFiles(syncDrive: true);
      }
      return;
    }

    await _autoSaveAttachedFiles(syncDrive: true);
  }

  Future<void> _autoSaveAttachedFiles({bool syncDrive = false}) async {
    final shouldSyncDrive =
        syncDrive && (driveMeta != null || _shouldAutoSyncGoogleDoc(status));
    if (meta == null && !shouldSyncDrive) return;

    autoSaveDebounce?.cancel();
    final version = ++autoSaveVersion;

    setState(() {
      autoSaving = true;
      message = 'Auto-saving attached note files...';
    });

    try {
      EntrySupportNoteMeta? updatedLocal;
      EntryDriveSupportNoteMeta? updatedDrive;
      Object? localError;
      StackTrace? localStackTrace;
      final appState = context.read<AppState>();

      if (meta != null) {
        try {
          updatedLocal = appState.isPayeMode
              ? await LocalSupportNoteService.savePayeNote(
                  entry: widget.entry,
                  initials: initialsController.text,
                  status: status,
                  noteText: noteController.text,
                )
              : await LocalSupportNoteService.saveNote(
                  entry: widget.entry,
                  initials: initialsController.text,
                  status: status,
                  noteText: noteController.text,
                );
        } catch (error, stackTrace) {
          localError = error;
          localStackTrace = stackTrace;
        }
      }

      if (shouldSyncDrive) {
        if (appState.isPayeMode) {
          final updatedEntry = _payeEntryWithCurrentNote();
          final file = await appState.savePayeNoteToDrive(updatedEntry);
          final discovered = await appState.findEntryNoteInCurrentDrive(
            updatedEntry,
          );

          updatedDrive =
              discovered?.copyWith(
                initials: _personNameForNote(
                  widget.entry,
                  fallback: initialsController.text,
                ),
                status: status,
                fileId: file.id,
                fileName: file.name,
                noteText: noteController.text,
                mimeType: file.mimeType,
                webViewLink: file.webViewLink,
                googleAccountEmail: appState.payeGoogleAccountEmail,
              ) ??
              EntryDriveSupportNoteMeta(
                entryId: widget.entry.id,
                initials: _personNameForNote(
                  widget.entry,
                  fallback: initialsController.text,
                ),
                status: status,
                fileId: file.id,
                fileName: file.name,
                noteText: noteController.text,
                mimeType: file.mimeType,
                parentFolderId: driveMeta?.parentFolderId,
                webViewLink: file.webViewLink,
                contentFormat: EntryDriveSupportNoteMeta.stableContentFormat,
                googleAccountEmail: appState.payeGoogleAccountEmail,
              );
          await driveService.saveSupportNoteMeta(updatedDrive);
        } else {
          final token = await appState.connectGoogleDrive();
          final folderId = await _clientNotesFolderId(appState, token);
          final googleAccountEmail = appState.workGoogleAccountEmail;
          updatedDrive = await driveService.saveSupportNote(
            accessToken: token,
            clientNotesFolderId: folderId,
            entry: widget.entry,
            initials: initialsController.text,
            status: status,
            noteText: LocalSupportNoteService.canonicalSupportNoteText(
              noteController.text,
            ),
            payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
            existingMeta: _driveMetaForAccount(driveMeta, googleAccountEmail),
            googleAccountEmail: googleAccountEmail,
          );
        }
      }

      if (updatedLocal == null && updatedDrive == null && localError != null) {
        Error.throwWithStackTrace(localError, localStackTrace!);
      }

      if (!mounted || version != autoSaveVersion) return;

      setState(() {
        meta = updatedLocal ?? meta;
        driveMeta = updatedDrive ?? driveMeta;
        message = 'Auto-saved attached note files.';
      });
      if (updatedLocal != null) {
        appState.upsertSupportNoteMeta(updatedLocal);
      }
      if (updatedDrive != null) {
        appState.upsertDriveSupportNoteMeta(updatedDrive);
      }
    } catch (error) {
      if (!mounted || version != autoSaveVersion) return;

      setState(() {
        message = 'Auto-save failed: ${_friendlyError(error)}';
      });
    } finally {
      if (mounted && version == autoSaveVersion) {
        setState(() {
          autoSaving = false;
        });
      }
    }
  }

  Future<void> _openFile() async {
    final current = meta;

    if (current == null) {
      setState(() {
        message = 'Create the local note file first.';
      });
      return;
    }

    setState(() {
      busy = true;
      message = 'Opening local note...';
    });

    try {
      await LocalSupportNoteService.openNote(current);

      if (!mounted) return;

      setState(() {
        message = 'Opened ${current.fileName}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not open note: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _openDriveFile() async {
    final current = driveMeta;
    final appState = context.read<AppState>();
    final accountMeta = _driveMetaForAccount(
      current,
      _currentGoogleAccountEmail(appState),
    );
    final link = current?.openLink;

    if (current == null ||
        accountMeta == null ||
        link == null ||
        link.isEmpty) {
      setState(() {
        message = 'Save the Google Doc under the selected account first.';
      });
      return;
    }

    await _launchDriveLink(Uri.parse(link));
  }

  Future<void> _syncFromGoogleDoc({bool silent = false}) async {
    final appState = context.read<AppState>();

    if (!silent) {
      setState(() {
        busy = true;
        message = 'Syncing from Google Doc...';
      });
    }

    try {
      final updated = await appState.syncEntryNoteFromGoogleDoc(
        entry: widget.entry,
        existingMeta: driveMeta,
        payeMode: appState.isPayeMode,
      );
      final loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);

      if (!mounted) return;

      suppressAutoSave = true;
      setState(() {
        driveMeta = updated;
        meta = loaded;
        initialsController.text = updated.initials;
        noteController.text = updated.noteText;
        status = updated.status;
        if (!silent) {
          message = 'Synced Google Doc edits into the app.';
        }
      });
      suppressAutoSave = false;
    } catch (error) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          message = 'Could not sync from Google Doc: ${_friendlyError(error)}';
        });
      }
    } finally {
      if (mounted && !silent) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Bad state: ')) {
      return text.replaceFirst('Bad state: ', '');
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final appState = context.watch<AppState>();
    final payeMode = appState.isPayeMode;
    final fallbackName = _bestPersonNameFallback(
      entry,
      meta,
      driveMeta,
      appState.clients,
    );
    final displayName = _personNameForNote(entry, fallback: fallbackName);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _noteTitleForEntry(
                    entry: entry,
                    status: status,
                    fallbackName: fallbackName,
                  ),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$displayName | ${formatDate(entry.date)}',
            style: const TextStyle(color: Color(0xFF8396C7)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _chooseFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(
              payeMode
                  ? 'Use Default PAYE Notes Folder'
                  : 'Use Default MR NOTES FOLDER',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: initialsController,
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Person name',
              helperText: 'Uses the app person name on saved notes.',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: NoteTextInputTools(
              controller: noteController,
              focusNode: noteFocusNode,
              title: payeMode ? 'PAYE note' : 'Support worker note',
              onSaveDraft: () => _saveDraftOnly('Draft saved in the app.'),
              onSaveDrive: _saveToDrive,
              onSyncDrive: () => _syncFromGoogleDoc(),
              syncStatusLabel: driveMeta == null
                  ? 'App note'
                  : 'Google Doc attached: ${driveMeta!.fileName}',
              actionsEnabled: !busy && !autoSaving,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            focusNode: noteFocusNode,
            enabled: !busy,
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: payeMode ? 'PAYE note' : 'Support worker note',
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in EntrySupportNoteStatus.values)
                FilterChip(
                  label: Text(item.label),
                  selected: status == item,
                  selectedColor: _statusColor(item).withValues(alpha: 0.25),
                  checkmarkColor: _statusColor(item),
                  side: BorderSide(color: _statusColor(item)),
                  onSelected: busy ? null : (_) => _changeStatus(item),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (meta != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Attached local file:\n${meta!.fileName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (driveMeta != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Google Docs note:\n${driveMeta!.fileName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: TextStyle(
                color:
                    message!.startsWith('Could') ||
                        message!.contains('failed') ||
                        message!.contains('Failed')
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF31E981),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (autoSaving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 4),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              payeMode
                  ? 'Save PAYE Note'
                  : meta == null
                  ? 'Create Local Note File'
                  : 'Update / Rename Local Note File',
            ),
          ),
          if (payeMode) ...[
            const SizedBox(height: 6),
            const Text(
              'This saves the PAYE note in the app. Use Google Docs to keep Drive matched.',
              style: TextStyle(color: Color(0xFF8396C7), fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _openFile,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Attached Local File'),
          ),
          const SizedBox(height: 8),
          if (payeMode) ...[
            OutlinedButton.icon(
              onPressed: busy ? null : _testGoogleDocsSave,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Test Google Docs Save & Remove'),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: busy ? null : _writeInGoogleDoc,
            icon: const Icon(Icons.edit_document),
            label: Text(
              driveMeta == null
                  ? 'Write in Google Docs'
                  : 'Open Live Google Doc',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _saveToDrive,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              driveMeta == null
                  ? payeMode
                        ? 'Save Google Docs Note'
                        : 'Create Google Docs Note'
                  : payeMode
                  ? 'Update Google Docs Note'
                  : 'Update Google Docs Note',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _saveDraftAndReturn,
            icon: const Icon(Icons.drafts_outlined),
            label: const Text('Save Draft & Return'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _openDriveFile,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Google Docs Note'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _syncFromGoogleDoc,
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Sync from Google Doc'),
          ),
          const SizedBox(height: 12),
          Text(
            payeMode
                ? 'PAYE Google Docs notes save to the PAYE notes folder for the selected PAYE Google account.'
                : 'The app note and Google Doc stay matched for this entry.',
            style: const TextStyle(color: Color(0xFF8396C7), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final EntrySupportNoteStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Future<bool> _confirmDeleteEntry(
  BuildContext context,
  WorkEntry entry, {
  String? displayName,
}) async {
  final payeMode = context.read<AppState>().isPayeMode;
  final person = displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : _personNameForNote(entry);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete this note?'),
            content: Text(
              payeMode
                  ? 'Delete $person on ${formatDate(entry.date)} from the app? '
                        'Any matching PAYE Google Doc under this Google account will be permanently deleted, not moved to bin.'
                  : 'Delete $person on ${formatDate(entry.date)} from the app? '
                        'Local saved note metadata will be permanently removed. This cannot be undone.',
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

EntryDriveSupportNoteMeta? _driveMetaForAccount(
  EntryDriveSupportNoteMeta? meta,
  String? accountEmail,
) {
  if (meta == null) return null;

  final selected = accountEmail?.trim().toLowerCase();
  final saved = meta.googleAccountEmail?.trim().toLowerCase();

  if (selected == null || selected.isEmpty) return meta;
  if (saved == null || saved.isEmpty) return null;

  return saved == selected ? meta : null;
}

EntrySupportNoteMeta? _preferredEntrySupportNoteMeta(
  EntrySupportNoteMeta? current,
  EntrySupportNoteMeta? incoming,
) {
  if (current == null) return incoming;
  if (incoming == null) return current;

  final currentRank = _supportNoteStatusRank(current.status);
  final incomingRank = _supportNoteStatusRank(incoming.status);
  if (incomingRank != currentRank) {
    return incomingRank > currentRank ? incoming : current;
  }

  if (current.noteText.trim().isEmpty && incoming.noteText.trim().isNotEmpty) {
    return incoming;
  }

  if (current.fileName.trim().isEmpty && incoming.fileName.trim().isNotEmpty) {
    return incoming;
  }

  return incoming;
}

EntryDriveSupportNoteMeta? _preferredDriveSupportNoteMeta(
  EntryDriveSupportNoteMeta? current,
  EntryDriveSupportNoteMeta? incoming,
) {
  if (current == null) return incoming;
  if (incoming == null) return current;

  final currentRank = _supportNoteStatusRank(current.status);
  final incomingRank = _supportNoteStatusRank(incoming.status);
  if (incomingRank != currentRank) {
    return incomingRank > currentRank ? incoming : current;
  }

  if (current.noteText.trim().isEmpty && incoming.noteText.trim().isNotEmpty) {
    return incoming;
  }

  if (current.fileId.trim().isEmpty && incoming.fileId.trim().isNotEmpty) {
    return incoming;
  }

  return incoming;
}

int _supportNoteStatusRank(EntrySupportNoteStatus status) {
  return switch (status) {
    EntrySupportNoteStatus.incomplete => 0,
    EntrySupportNoteStatus.inProgress => 1,
    EntrySupportNoteStatus.finished => 2,
    EntrySupportNoteStatus.submitted => 3,
  };
}

EntrySupportNoteStatus _preferredStatus(
  EntrySupportNoteStatus? current,
  EntrySupportNoteStatus? incoming,
) {
  if (current == null) {
    return incoming ?? EntrySupportNoteStatus.incomplete;
  }
  if (incoming == null) return current;

  return _supportNoteStatusRank(incoming) > _supportNoteStatusRank(current)
      ? incoming
      : current;
}

String? _currentGoogleAccountEmail(AppState appState) {
  return appState.isPayeMode
      ? appState.payeGoogleAccountEmail
      : appState.workGoogleAccountEmail;
}

String _defaultNoteText({
  required AppState appState,
  required WorkEntry entry,
  required EntrySupportNoteStatus status,
}) {
  return appState.isPayeMode
      ? LocalSupportNoteService.defaultPayeNoteTextForEntry(entry)
      : LocalSupportNoteService.defaultNoteTextForEntry(
          entry: entry,
          status: status,
        );
}

Color _statusColor(EntrySupportNoteStatus status) {
  switch (status) {
    case EntrySupportNoteStatus.incomplete:
      return const Color(0xFFFF6B6B);
    case EntrySupportNoteStatus.inProgress:
      return const Color(0xFFFFC857);
    case EntrySupportNoteStatus.finished:
      return const Color(0xFF31E981);
    case EntrySupportNoteStatus.submitted:
      return const Color(0xFF8B5CF6);
  }
}

Future<void> _launchDriveLink(Uri uri) async {
  final launched = kIsWeb
      ? await launchUrl(uri, webOnlyWindowName: '_blank')
      : await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched) {
    await launchUrl(uri);
  }
}

String _googleDocsLink(GoogleDriveFile file) {
  final link = file.webViewLink?.trim();
  if (link != null && link.isNotEmpty) return link;

  return 'https://docs.google.com/document/d/${Uri.encodeComponent(file.id)}/edit';
}
