import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/local_support_note_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';

String _noteTitleForEntry({
  required WorkEntry entry,
  required EntrySupportNoteStatus status,
}) {
  final initials = LocalSupportNoteService.defaultInitialsForEntry(entry);
  return LocalSupportNoteService.noteTitle(
    entry: entry,
    initials: initials,
    status: status,
  );
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
  EntrySupportNoteStatus? statusFilter;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<WorkEntry> _filtered(List<WorkEntry> entries) {
    final query = search.trim().toLowerCase();

    final filtered = entries.where((entry) {
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
        SnackBar(content: Text('Folder selection failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = context.watch<AppState>().entries;
    final entries = _filtered(allEntries);
    final nextActionEntries =
        allEntries.where((entry) => entry.nextActions.isNotEmpty).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.note_alt_outlined), text: 'Notes'),
                Tab(
                  icon: Icon(Icons.checklist_rtl_outlined),
                  text: 'Next Actions',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _NotesListTab(
                  entries: entries,
                  statusFilter: statusFilter,
                  searchController: searchController,
                  search: search,
                  onSearchChanged: (value) => setState(() => search = value),
                  onClearSearch: () {
                    setState(() {
                      searchController.clear();
                      search = '';
                    });
                  },
                  onStatusFilterChanged: (value) {
                    setState(() => statusFilter = value);
                  },
                  onChooseFolder: _chooseFolder,
                ),
                _NextActionsTab(entries: nextActionEntries),
              ],
            ),
          ),
        ],
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
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onStatusFilterChanged,
    required this.onChooseFolder,
  });

  final List<WorkEntry> entries;
  final EntrySupportNoteStatus? statusFilter;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<EntrySupportNoteStatus?> onStatusFilterChanged;
  final VoidCallback onChooseFolder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          title: 'Local Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onChooseFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Use Default MR NOTES FOLDER'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Create local support-note files attached to saved entries. Files are stored only in the folder you choose.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
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
    final actions = <_EntryAction>[];

    for (final entry in entries) {
      for (final action in entry.nextActions) {
        if (action.isCompleted) {
          actions.add(_EntryAction(entry: entry, action: action));
        }
      }
    }

    actions.sort((a, b) {
      final left =
          a.action.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.action.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return right.compareTo(left);
    });

    return actions;
  }

  void _toggleAction({
    required BuildContext context,
    required WorkEntry entry,
    required NextActionItem action,
    required bool completed,
  }) {
    final updatedActions = entry.nextActions.map((item) {
      if (item.id != action.id) return item;

      return item.copyWith(
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      );
    }).toList();

    context.read<AppState>().updateEntry(
      entry.copyWith(nextActions: updatedActions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;
    final completedActions = _completedActions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                'Actions come from the Next action(s) section when you finish a visit. Ticking an action logs the completion date and time.',
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
                          onChanged: (completed) => _toggleAction(
                            context: context,
                            entry: item.entry,
                            action: item.action,
                            completed: completed,
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
                      onChanged: (completed) => _toggleAction(
                        context: context,
                        entry: item.entry,
                        action: item.action,
                        completed: completed,
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
  });

  final WorkEntry entry;
  final NextActionItem action;
  final ValueChanged<bool> onChanged;

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
    final completedAt = action.completedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: action.isCompleted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF31E981),
        secondary: IconButton(
          tooltip: 'Open note',
          onPressed: () => _openNote(context),
          icon: const Icon(Icons.note_alt_outlined),
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
        subtitle: Text(
          completedAt == null
              ? '${entry.client} | ${formatDate(entry.date)}'
              : '${entry.client} | completed ${_dateTimeText(context, completedAt)}',
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
  EntrySupportNoteMeta? meta;

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
    final loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);

    if (!mounted) return;

    setState(() {
      meta = loaded;
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

  @override
  Widget build(BuildContext context) {
    final filter = widget.statusFilter;

    if (filter != null && meta?.status != filter) {
      return const SizedBox.shrink();
    }

    final status = meta?.status ?? EntrySupportNoteStatus.incomplete;

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
                _noteTitleForEntry(entry: widget.entry, status: status),
              ),
              subtitle: Text(
                '${widget.entry.client} | ${widget.entry.type.label} | ${widget.entry.baseMinutes} min | ${widget.entry.hours.toStringAsFixed(2)}h',
              ),
              trailing: _StatusPill(status: status),
            ),
            if (meta?.fileName.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              SelectableText(
                meta!.fileName,
                style: const TextStyle(color: Color(0xFF8396C7), fontSize: 12),
              ),
            ],
            if (widget.entry.supportNoteBreakdown.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                widget.entry.supportNoteBreakdown.trim(),
                style: const TextStyle(height: 1.35),
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
                  label: Text(meta == null ? 'Create Note' : 'Open Note'),
                ),
              ],
            ),
          ],
        ),
      ),
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
  final initialsController = TextEditingController();
  final noteController = TextEditingController();

  EntrySupportNoteStatus status = EntrySupportNoteStatus.incomplete;
  EntrySupportNoteMeta? meta;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    initialsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);

    if (!mounted) return;

    setState(() {
      meta = loaded;

      if (loaded == null) {
        initialsController.text =
            LocalSupportNoteService.defaultInitialsForEntry(widget.entry);
        noteController.text = LocalSupportNoteService.defaultNoteTextForEntry(
          entry: widget.entry,
          status: status,
        );
      } else {
        initialsController.text = loaded.initials;
        noteController.text = loaded.noteText;
        status = loaded.status;
      }
    });
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
      final updated = await LocalSupportNoteService.saveNote(
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

  Future<void> _changeStatus(EntrySupportNoteStatus next) async {
    setState(() {
      status = next;
    });

    if (meta == null) {
      noteController.text = LocalSupportNoteService.defaultNoteTextForEntry(
        entry: widget.entry,
        status: next,
      );
      return;
    }

    await _save();
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

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

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
                  _noteTitleForEntry(entry: entry, status: status),
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
            '${entry.client} | ${formatDate(entry.date)}',
            style: const TextStyle(color: Color(0xFF8396C7)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _chooseFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Use Default MR NOTES FOLDER'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: initialsController,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Person initials',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            enabled: !busy,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Support worker note',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
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
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: TextStyle(
                color:
                    message!.startsWith('Could') || message!.contains('failed')
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF31E981),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              meta == null
                  ? 'Create Local Note File'
                  : 'Update / Rename Local Note File',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _openFile,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Attached Local File'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Local only. This note is attached to the saved entry and saved only to the folder you choose. Changing status renames the attached local file.',
            style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
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
