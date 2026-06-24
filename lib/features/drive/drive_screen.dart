import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/models/google_drive_file.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/google_account_selector.dart';
import '../../shared/widgets/section_card.dart';

const _driveApiSetupUrl =
    'https://console.cloud.google.com/apis/library/drive.googleapis.com'
    '?project=support-worker-log';

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  final GoogleDriveService driveService = GoogleDriveService();

  bool connecting = false;
  bool connectingPersonal = false;
  bool connectingPaye = false;
  bool creatingFolders = false;
  bool creatingPersonalFolders = false;
  bool creatingPayeFolders = false;
  bool uploadingTemplates = false;
  bool loadingFiles = false;
  String? message;
  bool messageIsError = false;
  List<GoogleDriveFile> rootFiles = const [];
  List<GoogleDriveFile> templateFiles = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmGoogleAccounts();
    });
  }

  Future<void> _warmGoogleAccounts() async {
    if (!mounted) return;
    final appState = context.read<AppState>();

    try {
      for (final scope in GoogleExportAccountScope.values) {
        await appState.warmGoogleExportAccount(scope);
      }
    } catch (_) {
      // Connect handles real sign-in errors when the user taps the button.
    }
  }

  Future<String> _connectDrive(GoogleExportAccountScope scope) async {
    final token = await context.read<AppState>().connectGoogleDrive(
      scope: scope,
      forceRefresh: true,
    );
    return token;
  }

  Future<void> _connect() async {
    await _run(
      busy: () => connecting = true,
      idle: () => connecting = false,
      successMessage: 'Work Google Drive and Calendar connected.',
      action: () => _connectDrive(GoogleExportAccountScope.work),
    );
  }

  Future<void> _connectPersonal() async {
    await _run(
      busy: () => connectingPersonal = true,
      idle: () => connectingPersonal = false,
      successMessage: 'Personal Google Drive and Calendar connected.',
      action: () => _connectDrive(GoogleExportAccountScope.personal),
    );
  }

  Future<void> _connectPaye() async {
    await _run(
      busy: () => connectingPaye = true,
      idle: () => connectingPaye = false,
      successMessage: 'PAYE Google Drive connected.',
      action: () => _connectDrive(GoogleExportAccountScope.paye),
    );
  }

  Future<void> _createFolders() async {
    await _run(
      busy: () => creatingFolders = true,
      idle: () => creatingFolders = false,
      successMessage: 'Google Drive folders created.',
      action: () async {
        final appState = context.read<AppState>();
        final token = await appState.connectWorkGoogle();
        final setup = await driveService.createFolderSetup(accessToken: token);
        appState.updateSettings(setup.applyTo(appState.settings));
        await _loadFilesWithToken(token, setup.applyTo(appState.settings));
      },
    );
  }

  Future<void> _createPersonalFolders() async {
    await _run(
      busy: () => creatingPersonalFolders = true,
      idle: () => creatingPersonalFolders = false,
      successMessage: 'Personal Google Drive folder created.',
      action: () async {
        final appState = context.read<AppState>();
        final token = await appState.connectPersonalGoogle();
        final setup = await driveService.createPersonalFolderSetup(
          accessToken: token,
        );
        appState.updateSettings(setup.applyTo(appState.settings));
      },
    );
  }

  Future<void> _createPayeFolders() async {
    await _run(
      busy: () => creatingPayeFolders = true,
      idle: () => creatingPayeFolders = false,
      successMessage: 'PAYE Google Drive notes folder created.',
      action: () async {
        final appState = context.read<AppState>();
        final token = await appState.connectPayeGoogle();
        final setup = await driveService.createPayeFolderSetup(
          accessToken: token,
        );
        appState.updateSettings(setup.applyTo(appState.settings));
      },
    );
  }

  Future<void> _uploadTemplates() async {
    await _run(
      busy: () => uploadingTemplates = true,
      idle: () => uploadingTemplates = false,
      successMessage: 'Template files uploaded to Google Drive.',
      action: () async {
        final appState = context.read<AppState>();
        final folderId = appState.settings.googleDriveTemplatesFolderId;

        if (folderId == null || folderId.isEmpty) {
          throw StateError('Create the Google Drive folders first.');
        }

        final token = await appState.connectWorkGoogle();
        await driveService.uploadDefaultTemplates(
          accessToken: token,
          templatesFolderId: folderId,
        );
        await _loadFilesWithToken(token, appState.settings);
      },
    );
  }

  Future<void> _loadFiles() async {
    await _run(
      busy: () => loadingFiles = true,
      idle: () => loadingFiles = false,
      successMessage: 'Google Drive folders refreshed.',
      action: () async {
        final appState = context.read<AppState>();
        final token = await appState.connectWorkGoogle();
        await _loadFilesWithToken(token, appState.settings);
      },
    );
  }

  Future<void> _loadFilesWithToken(String token, AppSettings settings) async {
    final rootId = settings.googleDriveRootFolderId;
    final templatesId = settings.googleDriveTemplatesFolderId;

    final root = rootId == null || rootId.isEmpty
        ? <GoogleDriveFile>[]
        : await driveService.listFolder(accessToken: token, folderId: rootId);
    final templates = templatesId == null || templatesId.isEmpty
        ? <GoogleDriveFile>[]
        : await driveService.listFolder(
            accessToken: token,
            folderId: templatesId,
          );

    if (!mounted) return;

    setState(() {
      rootFiles = root;
      templateFiles = templates;
    });
  }

  Future<void> _run({
    required VoidCallback busy,
    required VoidCallback idle,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    setState(() {
      busy();
      message = null;
      messageIsError = false;
    });

    try {
      await action();

      if (!mounted) return;

      setState(() {
        message = successMessage;
        messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = _friendlyError(error);
        messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(idle);
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();

    if (text.startsWith('Bad state: ')) {
      return text.replaceFirst('Bad state: ', '');
    }

    if (text.startsWith('Instance of ')) {
      return 'Google Drive returned an unreadable browser error. Reconnect Drive and try again. If it repeats, enable Google Drive API in the Google Cloud project used by Firebase.';
    }

    return text;
  }

  Future<void> _openDriveFolder(String folderId) async {
    final uri = Uri.parse('https://drive.google.com/drive/folders/$folderId');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _openDriveFile(GoogleDriveFile file) async {
    final link = file.webViewLink;
    if (link == null || link.isEmpty) return;

    await launchUrl(Uri.parse(link), webOnlyWindowName: '_blank');
  }

  Future<void> _openDriveApiSetup() async {
    await launchUrl(Uri.parse(_driveApiSetupUrl), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final foldersReady =
        settings.googleDriveRootFolderId != null &&
        settings.googleDriveTemplatesFolderId != null;
    final personalFoldersReady =
        settings.personalGoogleDriveRootFolderId != null &&
        settings.personalGoogleDrivePersonalNotesFolderId != null;
    final payeFoldersReady =
        settings.payeGoogleDriveRootFolderId != null &&
        settings.payeGoogleDriveNotesFolderId != null;
    final anyBusy =
        connecting ||
        connectingPersonal ||
        connectingPaye ||
        creatingFolders ||
        creatingPersonalFolders ||
        creatingPayeFolders ||
        uploadingTemplates ||
        loadingFiles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Google Drive',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusRow(
                icon: Icons.cloud_done_outlined,
                label: 'Work Google account',
                value: appState.workGoogleServicesConnected
                    ? appState.workGoogleAccountEmail ?? 'Connected'
                    : 'Not connected',
                color: appState.workGoogleServicesConnected
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              _StatusRow(
                icon: Icons.folder_outlined,
                label: 'App folders',
                value: foldersReady ? 'Saved' : 'Not created',
                color: foldersReady
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              const SizedBox(height: 12),
              const GoogleAccountSelector(scope: GoogleExportAccountScope.work),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: connecting || anyBusy ? null : _connect,
                icon: connecting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_drive_outlined),
                label: Text(
                  connecting
                      ? 'Connecting Google Services'
                      : 'Connect Work Google',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: creatingFolders || anyBusy ? null : _createFolders,
                icon: creatingFolders
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: Text(
                  foldersReady ? 'Recreate App Folders' : 'Create App Folders',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openDriveApiSetup,
                icon: const Icon(Icons.settings_applications_outlined),
                label: const Text('Open Drive API Setup'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: !foldersReady || uploadingTemplates || anyBusy
                    ? null
                    : _uploadTemplates,
                icon: uploadingTemplates
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(
                  uploadingTemplates
                      ? 'Uploading Templates'
                      : 'Upload Templates',
                ),
              ),
              if (settings.googleDriveRootFolderId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openDriveFolder(settings.googleDriveRootFolderId!),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open Drive Folder'),
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: TextStyle(
                    color: messageIsError
                        ? const Color(0xFFFF5C5C)
                        : const Color(0xFF31E981),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Personal Google Drive',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusRow(
                icon: Icons.cloud_done_outlined,
                label: 'Personal Google account',
                value: appState.personalGoogleServicesConnected
                    ? appState.personalGoogleAccountEmail ?? 'Connected'
                    : 'Not connected',
                color: appState.personalGoogleServicesConnected
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              _StatusRow(
                icon: Icons.folder_outlined,
                label: 'Personal folder',
                value: personalFoldersReady ? 'Saved' : 'Not created',
                color: personalFoldersReady
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              const SizedBox(height: 12),
              const GoogleAccountSelector(
                scope: GoogleExportAccountScope.personal,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: connectingPersonal || anyBusy
                    ? null
                    : _connectPersonal,
                icon: connectingPersonal
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_outlined),
                label: Text(
                  connectingPersonal
                      ? 'Connecting Personal Google'
                      : 'Connect Personal Google',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: creatingPersonalFolders || anyBusy
                    ? null
                    : _createPersonalFolders,
                icon: creatingPersonalFolders
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: Text(
                  personalFoldersReady
                      ? 'Recreate Personal Folder'
                      : 'Create Personal Folder',
                ),
              ),
              if (settings.personalGoogleDriveRootFolderId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openDriveFolder(
                    settings.personalGoogleDriveRootFolderId!,
                  ),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open Personal Drive Folder'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'PAYE Google Drive',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusRow(
                icon: Icons.cloud_done_outlined,
                label: 'PAYE Google account',
                value: appState.payeGoogleServicesConnected
                    ? appState.payeGoogleAccountEmail ?? 'Connected'
                    : 'Not connected',
                color: appState.payeGoogleServicesConnected
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              _StatusRow(
                icon: Icons.folder_outlined,
                label: 'PAYE notes folder',
                value: payeFoldersReady ? 'Saved' : 'Not created',
                color: payeFoldersReady
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
              const SizedBox(height: 12),
              const GoogleAccountSelector(scope: GoogleExportAccountScope.paye),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: connectingPaye || anyBusy ? null : _connectPaye,
                icon: connectingPaye
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.business_center_outlined),
                label: Text(
                  connectingPaye
                      ? 'Connecting PAYE Google'
                      : 'Connect PAYE Google',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: creatingPayeFolders || anyBusy
                    ? null
                    : _createPayeFolders,
                icon: creatingPayeFolders
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: Text(
                  payeFoldersReady
                      ? 'Recreate PAYE Folder'
                      : 'Create PAYE Folder',
                ),
              ),
              if (settings.payeGoogleDriveRootFolderId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openDriveFolder(settings.payeGoogleDriveRootFolderId!),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open PAYE Drive Folder'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Drive Folders',
          child: _FolderList(settings: settings),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Files in Drive',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: loadingFiles || anyBusy || !foldersReady
                    ? null
                    : _loadFiles,
                icon: loadingFiles
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                label: Text(loadingFiles ? 'Refreshing' : 'Refresh Files'),
              ),
              const SizedBox(height: 12),
              _DriveFileGroup(
                title: 'Support Worker Log',
                files: rootFiles,
                onOpen: _openDriveFile,
              ),
              const SizedBox(height: 12),
              _DriveFileGroup(
                title: 'Templates',
                files: templateFiles,
                onOpen: _openDriveFile,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final folders = [
      ('Work - Support Worker Log', settings.googleDriveRootFolderId),
      ('Work - Templates', settings.googleDriveTemplatesFolderId),
      ('Work - Client Notes', settings.googleDriveClientNotesFolderId),
      ('Work - Calendar Exports', settings.googleDriveCalendarExportsFolderId),
      ('Work - Invoices', settings.googleDriveInvoicesFolderId),
      ('Work - Referrals', settings.googleDriveReferralsFolderId),
      (
        'Personal - Support Worker Log',
        settings.personalGoogleDriveRootFolderId,
      ),
      (
        'Personal - Personal Notes',
        settings.personalGoogleDrivePersonalNotesFolderId,
      ),
      ('PAYE - Support Worker Log', settings.payeGoogleDriveRootFolderId),
      ('PAYE - Notes', settings.payeGoogleDriveNotesFolderId),
    ];

    return Column(
      children: [
        for (final folder in folders)
          _StatusRow(
            icon: Icons.folder_outlined,
            label: folder.$1,
            value: folder.$2 == null ? 'Missing' : 'Ready',
            color: folder.$2 == null
                ? const Color(0xFFFFC857)
                : const Color(0xFF31E981),
          ),
      ],
    );
  }
}

class _DriveFileGroup extends StatelessWidget {
  const _DriveFileGroup({
    required this.title,
    required this.files,
    required this.onOpen,
  });

  final String title;
  final List<GoogleDriveFile> files;
  final ValueChanged<GoogleDriveFile> onOpen;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return EmptyState(message: 'No $title files loaded.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final file in files) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              file.isFolder
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
            ),
            title: Text(file.name),
            subtitle: Text(file.isFolder ? 'Folder' : file.mimeType),
            trailing: file.webViewLink == null
                ? null
                : IconButton(
                    tooltip: 'Open',
                    onPressed: () => onOpen(file),
                    icon: const Icon(Icons.open_in_new_outlined),
                  ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
