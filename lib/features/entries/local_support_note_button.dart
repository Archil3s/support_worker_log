import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/local_support_note_service.dart';
import '../../core/state/app_state.dart';

class LocalSupportNoteButton extends StatefulWidget {
  const LocalSupportNoteButton({super.key, required this.entry});

  final WorkEntry entry;

  @override
  State<LocalSupportNoteButton> createState() => _LocalSupportNoteButtonState();
}

class _LocalSupportNoteButtonState extends State<LocalSupportNoteButton> {
  EntrySupportNoteMeta? meta;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      builder: (_) => LocalSupportNoteSheet(entry: widget.entry),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = meta?.status;

    return TextButton.icon(
      onPressed: _openSheet,
      icon: Icon(
        Icons.note_alt_outlined,
        color: status == null ? null : _statusColor(status),
      ),
      label: Text(status == null ? 'Support Note' : status.label),
    );
  }
}

class LocalSupportNoteSheet extends StatefulWidget {
  const LocalSupportNoteSheet({super.key, required this.entry});

  final WorkEntry entry;

  @override
  State<LocalSupportNoteSheet> createState() => _LocalSupportNoteSheetState();
}

class _LocalSupportNoteSheetState extends State<LocalSupportNoteSheet> {
  final initialsController = TextEditingController();
  final noteController = TextEditingController();
  final GoogleDriveService driveService = GoogleDriveService();

  EntrySupportNoteStatus status = EntrySupportNoteStatus.incomplete;
  EntrySupportNoteMeta? meta;
  EntryDriveSupportNoteMeta? driveMeta;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmGoogleAccount();
    });
  }

  @override
  void dispose() {
    initialsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);
    final savedDrive = await driveService.loadSupportNoteMeta(widget.entry.id);
    final loadedDrive =
        _driveMetaForAccount(
          savedDrive,
          _currentGoogleAccountEmail(appState),
        ) ??
        await appState.findEntryNoteInCurrentDrive(widget.entry);

    if (!mounted) return;

    setState(() {
      meta = loaded;
      driveMeta = loadedDrive;

      if (loaded == null) {
        initialsController.text = loadedDrive?.initials.isNotEmpty == true
            ? loadedDrive!.initials
            : LocalSupportNoteService.defaultInitialsForEntry(widget.entry);
        noteController.text = loadedDrive?.noteText.trim().isNotEmpty == true
            ? loadedDrive!.noteText
            : _defaultNoteText(
                appState: appState,
                entry: widget.entry,
                status: loadedDrive?.status ?? status,
              );
        status = loadedDrive?.status ?? status;
      } else {
        initialsController.text = loaded.initials;
        noteController.text = loaded.noteText;
        status = loaded.status;
      }
    });
  }

  Future<void> _warmGoogleAccount() async {
    if (!mounted) return;

    try {
      final appState = context.read<AppState>();
      await appState.warmGoogleExportAccount(_currentGoogleScope(appState));
    } catch (_) {
      // Save/open buttons show real connection errors when tapped.
    }
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
    } catch (error) {
      if (!mounted) return;

      await _saveDraftOnly(
        'Could not create the local DOCX: $error\nDraft saved in the app.',
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _saveDraftOnly(String nextMessage) async {
    final updated = await LocalSupportNoteService.saveDraftMeta(
      entry: widget.entry,
      initials: initialsController.text,
      status: status,
      noteText: noteController.text,
    );

    if (!mounted) return;

    setState(() {
      meta = updated;
      message = nextMessage;
    });
  }

  Future<void> _saveDraftAndReturn() async {
    setState(() {
      busy = true;
      message = 'Saving note draft...';
    });

    try {
      await _saveDraftOnly(
        'Draft saved in the app. Connect Google Drive, then reopen this entry.',
      );

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

  Future<void> _saveGoogleDriveNote() async {
    setState(() {
      busy = true;
      message = 'Saving Google Drive note file...';
    });

    try {
      final appState = context.read<AppState>();
      if (appState.isPayeMode) {
        final updatedEntry = widget.entry.copyWith(
          supportNoteBreakdown: noteController.text,
        );
        final file = await appState.savePayeNoteToDrive(updatedEntry);
        final discovered = await appState.findEntryNoteInCurrentDrive(
          updatedEntry,
        );
        final updated =
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
        await driveService.saveSupportNoteMeta(updated);

        if (!mounted) return;

        setState(() {
          driveMeta = updated;
          message = 'Saved to Google Drive as ${updated.fileName}';
        });
        return;
      }

      final token = await appState.connectGoogleDrive();
      final clientNotesFolderId = await _clientNotesFolderId(appState, token);
      final googleAccountEmail = appState.workGoogleAccountEmail;
      final updated = await driveService.saveSupportNote(
        accessToken: token,
        clientNotesFolderId: clientNotesFolderId,
        entry: widget.entry,
        initials: initialsController.text,
        status: status,
        noteText: noteController.text,
        payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
        existingMeta: _driveMetaForAccount(driveMeta, googleAccountEmail),
        googleAccountEmail: googleAccountEmail,
      );

      if (!mounted) return;

      setState(() {
        driveMeta = updated;
        message = 'Saved to Google Drive as ${updated.fileName}';
      });
    } catch (error) {
      if (!mounted) return;

      await _saveDraftOnly(
        'Could not save to Google Drive: $error\nDraft saved in the app. '
        'Connect Google Drive, then reopen this entry and save again.',
      );
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
      noteController.text = _defaultNoteText(
        appState: context.read<AppState>(),
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

  Future<void> _openGoogleDriveNote() async {
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
        message =
            'Save the Google Drive note file under the selected account first.';
      });
      return;
    }

    await _launchDriveLink(Uri.parse(link));
  }

  Future<void> _openGoogleDriveFolder() async {
    final current = driveMeta;
    final appState = context.read<AppState>();
    final accountMeta = _driveMetaForAccount(
      current,
      _currentGoogleAccountEmail(appState),
    );
    final link = current?.folderOpenLink;

    if (current == null || accountMeta == null) {
      setState(() {
        message =
            'Save the Google Drive note file under the selected account first.';
      });
      return;
    }

    if (appState.isPayeMode) {
      final link = current.folderOpenLink;
      if (link == null || link.isEmpty) {
        setState(() {
          message = 'Open the PAYE Drive folder from the Drive tab.';
        });
        return;
      }

      await _launchDriveLink(Uri.parse(link));
      return;
    }

    if (link != null && link.isNotEmpty) {
      await _launchDriveLink(Uri.parse(link));
      return;
    }

    setState(() {
      busy = true;
      message = 'Opening client notes folder...';
    });

    try {
      final token = await appState.connectGoogleDrive();
      final clientNotesFolderId = await _clientNotesFolderId(appState, token);
      final folder = await driveService.findOrCreateSupportNoteFolder(
        accessToken: token,
        clientNotesFolderId: clientNotesFolderId,
        entry: widget.entry,
        payPeriodAnchorDate: appState.settings.payPeriodAnchorDate,
      );
      final folderLink =
          'https://drive.google.com/drive/folders/'
          '${Uri.encodeComponent(folder.id)}';

      await _launchDriveLink(Uri.parse(folderLink));

      if (!mounted) return;

      final updatedMeta = current.copyWith(parentFolderId: folder.id);
      await driveService.saveSupportNoteMeta(updatedMeta);

      if (!mounted) return;

      setState(() {
        driveMeta = updatedMeta;
        message = 'Opened client notes folder.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not open client notes folder: $error';
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
              const Expanded(
                child: Text(
                  'Support Note',
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
            '${entry.client} | ${entry.date.day}/${entry.date.month}/${entry.date.year}',
            style: const TextStyle(color: Color(0xFF8396C7)),
          ),
          const SizedBox(height: 16),
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
          if (driveMeta != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Google Drive DOCX note:\n${driveMeta!.fileName}',
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _saveGoogleDriveNote,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              driveMeta == null
                  ? 'Create Google Drive DOCX Note'
                  : 'Update Google Drive DOCX Note',
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
            onPressed: busy ? null : _openGoogleDriveNote,
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Open Google Drive DOCX Note'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _openGoogleDriveFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(
              context.watch<AppState>().isPayeMode
                  ? 'Open PAYE Note Folder'
                  : 'Load Client Folder',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Local notes stay attached to this entry card. Drive DOCX notes save under Client Notes.',
            style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
          ),
        ],
      ),
    );
  }
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

GoogleExportAccountScope _currentGoogleScope(AppState appState) {
  return appState.isPayeMode
      ? GoogleExportAccountScope.paye
      : GoogleExportAccountScope.work;
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
