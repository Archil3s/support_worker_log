import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/models/google_drive_file.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/local_support_note_service.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/google_drive_connection_warning.dart';
import '../../shared/widgets/note_text_input_tools.dart';
import '../../shared/widgets/notes_storage_gate.dart';

double _supportNoteSheetHeight(BuildContext context) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
  final visibleHeight = screenHeight - keyboardBottom - 24;
  final maxHeight = screenHeight * 0.94;
  final height = visibleHeight < maxHeight ? visibleHeight : maxHeight;

  return height < 360 ? 360 : height;
}

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
    final appState = context.watch<AppState>();
    final locked = !appState.notesStorageReadyForScope(
      _currentGoogleScope(appState),
    );
    final status = meta?.status;

    return TextButton.icon(
      onPressed: _openSheet,
      icon: Icon(
        locked ? Icons.lock_outline : Icons.note_alt_outlined,
        color: locked || status == null ? null : _statusColor(status),
      ),
      label: Text(
        locked
            ? 'Notes Locked'
            : status == null
            ? 'Support Note'
            : status.label,
      ),
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
  final noteFocusNode = FocusNode();
  final GoogleDriveService driveService = GoogleDriveService();

  EntrySupportNoteStatus status = EntrySupportNoteStatus.incomplete;
  EntrySupportNoteMeta? meta;
  EntryDriveSupportNoteMeta? driveMeta;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmGoogleAccount();
    });
  }

  @override
  void dispose() {
    draftAutosaveTimer?.cancel();
    initialsController.dispose();
    noteController.dispose();
    noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    EntrySupportNoteMeta? loaded;
    EntryDriveSupportNoteMeta? loadedDrive;
    final googleAccountEmail = _currentGoogleAccountEmail(appState);

    try {
      loaded = await LocalSupportNoteService.loadMeta(widget.entry.id);
      loaded = _preferredEntrySupportNoteMeta(
        loaded,
        appState.supportNoteMetaFor(widget.entry.id),
      );
    } catch (_) {
      loaded = appState.supportNoteMetaFor(widget.entry.id);
    }

    try {
      final savedDrive = await driveService.loadSupportNoteMeta(
        widget.entry.id,
      );
      final savedDriveForAccount = _driveMetaForAccount(
        savedDrive,
        googleAccountEmail,
      );
      final syncedDriveForAccount = _driveMetaForAccount(
        appState.driveSupportNoteMetaFor(widget.entry.id),
        googleAccountEmail,
      );
      loadedDrive = _preferredDriveSupportNoteMeta(
        savedDriveForAccount,
        syncedDriveForAccount,
      );
      loadedDrive ??= await appState.findEntryNoteInCurrentDrive(widget.entry);
    } catch (_) {
      loadedDrive = _driveMetaForAccount(
        appState.driveSupportNoteMetaFor(widget.entry.id),
        googleAccountEmail,
      );
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

      if (loaded == null) {
        initialsController.text = _personNameForNote(
          widget.entry,
          fallback: _bestPersonNameFallback(
            widget.entry,
            null,
            loadedDrive,
            appState.clients,
          ),
        );
        noteController.text = loadedDrive?.noteText.trim().isNotEmpty == true
            ? loadedDrive!.noteText
            : _defaultNoteText(
                appState: appState,
                entry: widget.entry,
                status: loadedDrive?.status ?? status,
              );
        status = loadedDrive?.status ?? status;
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
      draftAutosaveReady = true;
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
      message = 'Saving note in the app...';
    });

    try {
      final appState = context.read<AppState>();
      final payeMode = appState.isPayeMode;
      if (payeMode && status != EntrySupportNoteStatus.submitted) {
        status = EntrySupportNoteStatus.finished;
      }
      await _saveDraftOnly('Note saved in the app.', showMessage: false);

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
        message = payeMode
            ? 'PAYE note saved in the app and as ${updated.fileName}'
            : 'Saved locally as ${updated.fileName}';
      });
      context.read<AppState>().upsertSupportNoteMeta(updated);
    } catch (error) {
      if (!mounted) return;

      await _saveDraftOnly(
        'Note saved in the app. Optional local DOCX was not created: $error',
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
    final appState = context.read<AppState>();
    final updated = await LocalSupportNoteService.saveDraftMeta(
      entry: widget.entry,
      initials: initialsController.text,
      status: status,
      noteText: noteController.text,
    );

    if (!mounted) return;

    setState(() {
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
      message = 'Saving note in the app before Google Drive...';
    });

    try {
      final appState = context.read<AppState>();
      await _saveDraftOnly('Note saved in the app.', showMessage: false);
      if (appState.isPayeMode) {
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
      appState.upsertDriveSupportNoteMeta(updated);
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
            'Temporary Google Doc opened. It will be removed from Drive in '
            '45 seconds.';
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
    setState(() {
      status = next;
    });

    if (meta == null) {
      noteController.text = _defaultNoteText(
        appState: context.read<AppState>(),
        entry: widget.entry,
        status: next,
      );
      await _saveDraftOnly('Draft status saved.', showMessage: false);
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

  Future<void> _openLocalFolder() async {
    final current = meta;

    if (current == null) {
      setState(() {
        message = 'Create the local note file first.';
      });
      return;
    }

    setState(() {
      busy = true;
      message = 'Opening local note folder...';
    });

    try {
      await LocalSupportNoteService.openNoteFolder(current);

      if (!mounted) return;

      setState(() {
        message = 'Opened folder for ${current.fileName}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not open note folder: $error';
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
      appState.upsertDriveSupportNoteMeta(updatedMeta);

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
    final appState = context.watch<AppState>();
    final scope = _currentGoogleScope(appState);
    final payeMode = appState.isPayeMode;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final displayName = _personNameForNote(
      entry,
      fallback: _bestPersonNameFallback(
        entry,
        meta,
        driveMeta,
        appState.clients,
      ),
    );

    if (!appState.notesStorageReadyForScope(scope)) {
      return SizedBox(
        height: _supportNoteSheetHeight(context),
        child: NotesStorageGate(
          scope: scope,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: const SizedBox.shrink(),
        ),
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: SizedBox(
        height: _supportNoteSheetHeight(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardBottom + 320),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              '$displayName | ${entry.date.day}/${entry.date.month}/${entry.date.year}',
              style: const TextStyle(color: Color(0xFF8396C7)),
            ),
            const SizedBox(height: 16),
            GoogleDriveConnectionWarning(
              scope: _currentGoogleScope(context.watch<AppState>()),
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
              textCapitalization: TextCapitalization.words,
              scrollPadding: EdgeInsets.only(bottom: keyboardBottom + 140),
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
                title: 'Support worker note',
                onChanged: (_) => _scheduleDraftAutosave(),
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
              scrollPadding: EdgeInsets.only(bottom: keyboardBottom + 320),
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
                    payeMode
                        ? 'Google Docs note:\n${driveMeta!.fileName}'
                        : 'Google Drive DOCX note:\n${driveMeta!.fileName}',
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
                          message!.contains('failed')
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
                payeMode ? 'Save PAYE Note in App' : 'Save Note in App',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              payeMode
                  ? 'This saves the PAYE note after Firebase sync and Google Drive are connected.'
                  : 'This saves the note after Firebase sync and Google Drive are connected.',
              style: const TextStyle(color: Color(0xFF8396C7), fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _openFile,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Attached Local File'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _openLocalFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open Local Note Folder'),
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
            OutlinedButton.icon(
              onPressed: busy ? null : _saveGoogleDriveNote,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                driveMeta == null
                    ? payeMode
                          ? 'Save Google Docs Note'
                          : 'Create Google Drive DOCX Note'
                    : payeMode
                    ? 'Update Google Docs Note'
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
              label: Text(
                payeMode
                    ? 'Open Google Docs Note'
                    : 'Open Google Drive DOCX Note',
              ),
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
              'Notes stay locked unless Firebase sync and Google Drive are connected.',
              style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
            ),
          ],
        ),
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

GoogleExportAccountScope _currentGoogleScope(AppState appState) {
  return appState.isPayeMode
      ? GoogleExportAccountScope.paye
      : GoogleExportAccountScope.work;
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
