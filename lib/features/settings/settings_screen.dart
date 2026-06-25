// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../core/services/export_service.dart';
import '../../core/services/pdf_timesheet_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../shared/widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const ExportService _exportService = ExportService();
  static const PdfTimesheetService _pdfTimesheetService = PdfTimesheetService();

  late final TextEditingController hourlyRateController;
  late final TextEditingController fuelRateController;
  late final TextEditingController accRateController;
  late final TextEditingController gstRateController;
  late final TextEditingController kiwiSaverRateController;
  final clientController = TextEditingController();
  final noteController = TextEditingController();

  PayPeriodRange timesheetRange = currentFortnight();

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
    accRateController = TextEditingController(
      text: (settings.accRate * 100).toStringAsFixed(2),
    );
    gstRateController = TextEditingController(
      text: (settings.gstRate * 100).toStringAsFixed(2),
    );
    kiwiSaverRateController = TextEditingController(
      text: (settings.kiwiSaverRate * 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    hourlyRateController.dispose();
    fuelRateController.dispose();
    accRateController.dispose();
    gstRateController.dispose();
    kiwiSaverRateController.dispose();
    clientController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void saveRates() {
    final appState = context.read<AppState>();
    final settings = appState.settings;

    final hourlyRate = double.tryParse(hourlyRateController.text.trim());
    final fuelRate = double.tryParse(fuelRateController.text.trim());
    final accRate = double.tryParse(accRateController.text.trim());
    final gstRate = double.tryParse(gstRateController.text.trim());
    final kiwiSaverRate = double.tryParse(kiwiSaverRateController.text.trim());

    appState.updateSettings(
      settings.copyWith(
        hourlyRate: hourlyRate ?? settings.hourlyRate,
        fuelRate: fuelRate ?? settings.fuelRate,
        accRate: accRate == null ? settings.accRate : accRate / 100,
        gstRate: gstRate == null ? settings.gstRate : gstRate / 100,
        kiwiSaverRate: kiwiSaverRate == null
            ? settings.kiwiSaverRate
            : kiwiSaverRate / 100,
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rates saved')));
  }

  void addClient() {
    final added = context.read<AppState>().addClient(clientController.text);

    if (added) {
      clientController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client added')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client name is empty or already exists')),
    );
  }

  Future<void> renameClient(String client) async {
    final controller = TextEditingController(text: client);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Client'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Client name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null) return;

    final renamed = context.read<AppState>().renameClient(
      oldName: client,
      newName: newName,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          renamed
              ? 'Client renamed'
              : 'Could not rename client. The name may already exist.',
        ),
      ),
    );
  }

  Future<void> confirmRemoveClient(String client) async {
    final appState = context.read<AppState>();
    final usageCount = appState.clientUsageCount(client);
    final payeMode = appState.isPayeMode;

    if (!payeMode && usageCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete "$client" because it is used by $usageCount entr${usageCount == 1 ? 'y' : 'ies'}. Rename it instead.',
          ),
        ),
      );
      return;
    }

    if (!payeMode && appState.clients.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one client is required')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(payeMode ? 'Remove PAYE person?' : 'Delete Client?'),
          content: Text(
            payeMode
                ? 'Remove "$client" from the PAYE people list? Existing saved notes stay under that name.'
                : 'Delete "$client"? This client is not used by any entries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(payeMode ? 'Remove' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final removed = payeMode
        ? context.read<AppState>().removeClientFromList(client)
        : context.read<AppState>().removeClient(client);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? payeMode
                    ? 'PAYE person removed'
                    : 'Client deleted'
              : payeMode
              ? 'PAYE person could not be removed'
              : 'Client could not be deleted',
        ),
      ),
    );
  }

  Future<void> confirmClearClients() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove all PAYE people?'),
          content: const Text(
            'This clears the PAYE people dropdown. Existing saved notes and entries are not deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Remove All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final count = context.read<AppState>().clearClientList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed $count PAYE people from the list')),
    );
  }

  void addNoteChip() {
    final appState = context.read<AppState>();
    final settings = appState.settings;
    final note = noteController.text.trim();

    if (note.isEmpty || settings.noteOptions.contains(note)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note chip is empty or already exists')),
      );
      return;
    }

    appState.updateSettings(
      settings.copyWith(noteOptions: [...settings.noteOptions, note]..sort()),
    );

    noteController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note chip added')));
  }

  void removeNoteChip(String note) {
    final appState = context.read<AppState>();
    final settings = appState.settings;

    if (settings.noteOptions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one note chip is required')),
      );
      return;
    }

    appState.updateSettings(
      settings.copyWith(
        noteOptions: settings.noteOptions
            .where((item) => item != note)
            .toList(),
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note chip removed')));
  }

  void showCurrentTimesheetPeriod() {
    setState(() => timesheetRange = currentFortnight());
  }

  void showPreviousTimesheetPeriod() {
    setState(() => timesheetRange = timesheetRange.previous);
  }

  void showNextTimesheetPeriod() {
    setState(() => timesheetRange = timesheetRange.next);
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

  Future<void> printTimesheet() async {
    final appState = context.read<AppState>();

    await Printing.layoutPdf(
      name:
          'support_worker_timesheet_${formatDate(timesheetRange.start)}_${formatDate(timesheetRange.end)}.pdf',
      onLayout: (format) {
        return _pdfTimesheetService.buildTimesheetPdf(
          entries: appState.entries,
          settings: appState.settings,
          range: timesheetRange,
          pageFormat: format,
        );
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timesheet sent to print/export')),
    );
  }

  Future<void> copyJsonBackup() async {
    final appState = context.read<AppState>();

    final backup = _exportService.buildJsonBackup(
      entries: appState.workEntries,
      clients: appState.workClients,
      settings: appState.settings,
      payeClients: appState.payeClients,
      payeEntries: appState.payeEntries,
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
      entries: appState.workEntries,
      clients: appState.workClients,
      settings: appState.settings,
      payeClients: appState.payeClients,
      payeEntries: appState.payeEntries,
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
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will remove all entries, clients, and custom settings from this device. Type CLEAR to confirm.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Type CLEAR',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(controller.text.trim().toUpperCase() == 'CLEAR');
              },
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (confirmed != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clear data cancelled')));
      return;
    }

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
              TextField(
                controller: accRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'ACC rate',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gstRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'GST rate',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kiwiSaverRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'KiwiSaver rate',
                  suffixText: '%',
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
          title: appState.isPayeMode ? 'PAYE People' : 'Client Manager',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: clientController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appState.isPayeMode
                            ? 'New PAYE person'
                            : 'New client',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: addClient, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 12),
              for (final client in appState.clients)
                _ClientManagerTile(
                  client: client,
                  usageCount: appState.isPayeMode
                      ? null
                      : appState.clientUsageCount(client),
                  canDelete:
                      appState.isPayeMode || appState.canRemoveClient(client),
                  deleteLabel: appState.isPayeMode
                      ? 'Remove from PAYE list'
                      : null,
                  onRename: () => renameClient(client),
                  onDelete: () => confirmRemoveClient(client),
                ),
              if (appState.isPayeMode) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: appState.clients.isEmpty
                      ? null
                      : confirmClearClients,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Remove All PAYE People'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Note Chip Manager',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'New note chip',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: addNoteChip,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final note in appState.settings.noteOptions)
                    InputChip(
                      label: Text(note),
                      onDeleted: () => removeNoteChip(note),
                    ),
                ],
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
          title: 'Timesheet Export',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(timesheetRange.start)} - ${formatDate(timesheetRange.end)}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: showPreviousTimesheetPeriod,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: showCurrentTimesheetPeriod,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Current'),
                  ),
                  OutlinedButton.icon(
                    onPressed: showNextTimesheetPeriod,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: printTimesheet,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Timesheet'),
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

class _ClientManagerTile extends StatelessWidget {
  const _ClientManagerTile({
    required this.client,
    required this.canDelete,
    this.usageCount,
    this.deleteLabel,
    required this.onRename,
    required this.onDelete,
  });

  final String client;
  final int? usageCount;
  final bool canDelete;
  final String? deleteLabel;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final usage = usageCount;
    final usageText = usage == null
        ? 'PAYE list only. Existing entries are not kept in this list.'
        : usage == 0
        ? 'Unused'
        : 'Used in $usage entr${usage == 1 ? 'y' : 'ies'}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(client),
      subtitle: Text(usageText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: usage == null ? 'Rename PAYE person' : 'Rename client',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          IconButton(
            tooltip:
                deleteLabel ??
                (canDelete
                    ? 'Delete unused client'
                    : 'Cannot delete a client used by entries'),
            icon: const Icon(Icons.delete_outline),
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}
