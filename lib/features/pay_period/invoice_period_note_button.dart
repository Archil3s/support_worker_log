import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/invoice_period_note_service.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../shared/widgets/google_drive_connection_warning.dart';

class InvoicePeriodNoteButton extends StatefulWidget {
  const InvoicePeriodNoteButton({
    super.key,
    required this.invoiceNumber,
    required this.range,
    required this.entries,
    required this.settings,
  });

  final int invoiceNumber;
  final PayPeriodRange range;
  final List<WorkEntry> entries;
  final AppSettings settings;

  @override
  State<InvoicePeriodNoteButton> createState() =>
      _InvoicePeriodNoteButtonState();
}

class _InvoicePeriodNoteButtonState extends State<InvoicePeriodNoteButton> {
  InvoicePeriodNoteMeta? meta;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final loaded = await InvoicePeriodNoteService.loadMeta(widget.range);

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
      builder: (_) => InvoicePeriodNoteSheet(
        invoiceNumber: widget.invoiceNumber,
        range: widget.range,
        entries: widget.entries,
        settings: widget.settings,
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = meta?.status;

    return IconButton(
      tooltip: status == null ? 'Invoice period note' : status.label,
      onPressed: _openSheet,
      icon: Icon(
        Icons.note_alt_outlined,
        color: status == null ? null : _statusColor(status),
      ),
    );
  }
}

class InvoicePeriodNoteSheet extends StatefulWidget {
  const InvoicePeriodNoteSheet({
    super.key,
    required this.invoiceNumber,
    required this.range,
    required this.entries,
    required this.settings,
  });

  final int invoiceNumber;
  final PayPeriodRange range;
  final List<WorkEntry> entries;
  final AppSettings settings;

  @override
  State<InvoicePeriodNoteSheet> createState() => _InvoicePeriodNoteSheetState();
}

class _InvoicePeriodNoteSheetState extends State<InvoicePeriodNoteSheet> {
  final initialsController = TextEditingController();
  final noteController = TextEditingController();

  InvoicePeriodNoteStatus status = InvoicePeriodNoteStatus.incomplete;
  InvoicePeriodNoteMeta? meta;
  bool busy = false;
  String? message;
  bool draftAutosaveReady = false;
  Timer? draftAutosaveTimer;

  @override
  void initState() {
    super.initState();
    initialsController.addListener(_scheduleDraftAutosave);
    noteController.addListener(_scheduleDraftAutosave);
    unawaited(_load());
  }

  @override
  void dispose() {
    draftAutosaveTimer?.cancel();
    initialsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await InvoicePeriodNoteService.loadMeta(widget.range);

    if (!mounted) return;

    setState(() {
      meta = loaded;

      if (loaded != null) {
        initialsController.text = loaded.initials;
        noteController.text = loaded.noteText;
        status = loaded.status;
      }
      draftAutosaveReady = true;
    });
  }

  Future<void> _chooseFolder() async {
    setState(() {
      busy = true;
      message = 'Choose C:\\Users\\Danie\\MR NOTES FOLDER in Chrome.';
    });

    try {
      await InvoicePeriodNoteService.chooseFolder();

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
      message = 'Saving local invoice-period note...';
    });

    try {
      final updated = await InvoicePeriodNoteService.saveNote(
        invoiceNumber: widget.invoiceNumber,
        range: widget.range,
        entries: widget.entries,
        settings: widget.settings,
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

      await _saveDraftOnly(
        'Could not create the local invoice note: $error\n'
        'Draft saved in the app.',
      );
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
    final updated = await InvoicePeriodNoteService.saveDraftMeta(
      invoiceNumber: widget.invoiceNumber,
      range: widget.range,
      initials: initialsController.text,
      status: status,
      noteText: noteController.text,
    );

    if (!mounted) return;

    setState(() {
      meta = updated;
      if (showMessage) message = nextMessage;
    });
  }

  void _scheduleDraftAutosave() {
    if (!draftAutosaveReady || busy) return;

    draftAutosaveTimer?.cancel();
    draftAutosaveTimer = Timer(const Duration(milliseconds: 900), () async {
      try {
        await _saveDraftOnly('Draft autosaved in the app.', showMessage: false);
      } catch (_) {
        // Explicit save buttons show errors.
      }
    });
  }

  Future<void> _saveDraftAndReturn() async {
    setState(() {
      busy = true;
      message = 'Saving invoice note draft...';
    });

    try {
      await _saveDraftOnly(
        'Draft saved in the app. Reopen this invoice note to finish it.',
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not save invoice note draft: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _changeStatus(InvoicePeriodNoteStatus next) async {
    setState(() {
      status = next;
    });
    _scheduleDraftAutosave();

    if (meta != null && initialsController.text.trim().isNotEmpty) {
      await _save();
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
      await InvoicePeriodNoteService.openNote(current);

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
    final periodText =
        '${_date(widget.range.start)} - ${_date(widget.range.end)}';

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
                  'Invoice ${widget.invoiceNumber} Note',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(periodText, style: const TextStyle(color: Color(0xFF8396C7))),
          const SizedBox(height: 16),
          const GoogleDriveConnectionWarning(
            scope: GoogleExportAccountScope.work,
            compact: true,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _chooseFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Choose MR NOTES FOLDER'),
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
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '2-week invoice period note',
              hintText: 'Write notes for this 2-week invoice period...',
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
              for (final item in InvoicePeriodNoteStatus.values)
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
                  ? 'Create Local Period Note'
                  : 'Update / Rename Local Period Note',
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
            onPressed: busy ? null : _openFile,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Attached Local File'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Local only. This note is attached to this 2-week invoice period row and saved only to the local folder you select.',
            style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }
}

Color _statusColor(InvoicePeriodNoteStatus status) {
  switch (status) {
    case InvoicePeriodNoteStatus.incomplete:
      return const Color(0xFFFF6B6B);
    case InvoicePeriodNoteStatus.inProgress:
      return const Color(0xFFFFC857);
    case InvoicePeriodNoteStatus.finished:
      return const Color(0xFF31E981);
    case InvoicePeriodNoteStatus.submitted:
      return const Color(0xFF8B5CF6);
  }
}
