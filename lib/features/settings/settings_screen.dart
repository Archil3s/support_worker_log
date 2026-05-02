// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/export_service.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const ExportService _exportService = ExportService();

  late final TextEditingController hourlyRateController;
  late final TextEditingController fuelRateController;
  final clientController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final settings = context.read<AppState>().settings;
    hourlyRateController = TextEditingController(
      text: settings.hourlyRate.toStringAsFixed(2),
    );
    fuelRateController = TextEditingController(
      text: settings.fuelRate.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    hourlyRateController.dispose();
    fuelRateController.dispose();
    clientController.dispose();
    super.dispose();
  }

  void saveRates() {
    final appState = context.read<AppState>();
    final settings = appState.settings;

    final hourlyRate = double.tryParse(hourlyRateController.text.trim());
    final fuelRate = double.tryParse(fuelRateController.text.trim());

    appState.updateSettings(
      settings.copyWith(
        hourlyRate: hourlyRate ?? settings.hourlyRate,
        fuelRate: fuelRate ?? settings.fuelRate,
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rates saved')));
  }

  Future<void> copyFullSummary() async {
    final appState = context.read<AppState>();

    final summary = _exportService.buildFullSummary(
      entries: appState.entries,
      settings: appState.settings,
    );

    await Clipboard.setData(ClipboardData(text: summary));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Full summary copied')));
  }

  Future<void> copyCsv() async {
    final appState = context.read<AppState>();

    final csv = _exportService.buildEntriesCsv(
      entries: appState.entries,
      settings: appState.settings,
    );

    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV copied')));
  }

  Future<void> previewCsv() async {
    final appState = context.read<AppState>();

    final csv = _exportService.buildEntriesCsv(
      entries: appState.entries,
      settings: appState.settings,
    );

    await _showPreviewDialog(
      title: 'CSV Preview',
      content: csv,
      copyLabel: 'Copy CSV',
      copiedMessage: 'CSV copied',
    );
  }

  Future<void> copyJsonBackup() async {
    final appState = context.read<AppState>();

    final backup = _exportService.buildJsonBackup(
      entries: appState.entries,
      clients: appState.clients,
      settings: appState.settings,
    );

    await Clipboard.setData(ClipboardData(text: backup));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON backup copied')));
  }

  Future<void> previewJsonBackup() async {
    final appState = context.read<AppState>();

    final backup = _exportService.buildJsonBackup(
      entries: appState.entries,
      clients: appState.clients,
      settings: appState.settings,
    );

    await _showPreviewDialog(
      title: 'JSON Backup Preview',
      content: backup,
      copyLabel: 'Copy JSON',
      copiedMessage: 'JSON backup copied',
    );
  }

  Future<void> importJsonBackup() async {
    final controller = TextEditingController();

    final imported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import JSON Backup'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: controller,
              minLines: 10,
              maxLines: 18,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste JSON backup here',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (imported != true) {
      controller.dispose();
      return;
    }

    try {
      final backup = _exportService.parseJsonBackup(controller.text);
      controller.dispose();

      await context.read<AppState>().restoreFromBackup(backup);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON backup imported')));
    } catch (error) {
      controller.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  Future<void> confirmClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This will remove all entries, clients, and custom settings from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await context.read<AppState>().clearAllData();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All data cleared')));
  }

  Future<void> _showPreviewDialog({
    required String title,
    required String content,
    required String copyLabel,
    required String copiedMessage,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(copiedMessage)));
                }
              },
              child: Text(copyLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Rates',
          child: Column(
            children: [
              TextField(
                controller: hourlyRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Hourly rate',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fuelRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Fuel / km rate',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveRates,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Rates'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Clients',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: clientController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'New client',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      context.read<AppState>().addClient(clientController.text);
                      clientController.clear();
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final client in appState.clients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(client),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      context.read<AppState>().removeClient(client);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Data Export',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: copyFullSummary,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy Full Summary'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: copyCsv,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Copy CSV'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: previewCsv,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Preview CSV'),
              ),
              const SizedBox(height: 12),
              Text(
                'Exports include ${appState.entries.length} entries.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'JSON Backup',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: copyJsonBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Copy JSON Backup'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: previewJsonBackup,
                icon: const Icon(Icons.code_outlined),
                label: const Text('Preview JSON Backup'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: importJsonBackup,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Import JSON Backup'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: confirmClearAllData,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Clear All Data'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
