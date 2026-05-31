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
  return '$initials | ${status.label} | ${formatDate(entry.date)}';
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
    final entries = _filtered(context.watch<AppState>().entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Local Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _chooseFolder,
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
                onChanged: (value) => setState(() => search = value),
                decoration: InputDecoration(
                  labelText: 'Search notes',
                  helperText: 'Search by person, date, or support type',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: search.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              searchController.clear();
                              search = '';
                            });
                          },
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
                onChanged: (value) => setState(() => statusFilter = value),
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
