// ignore_for_file: use_build_context_synchronously

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../core/services/excel_export_service.dart';
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
  static const ExcelExportService _excelExportService = ExcelExportService();
  static const PdfTimesheetService _pdfTimesheetService = PdfTimesheetService();

  late final TextEditingController hourlyRateController;
  late final TextEditingController fuelRateController;
  final clientController = TextEditingController();

  PayPeriodRange excelRange = currentFortnight();

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

    if (usageCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete "$client" because it is used by $usageCount entr${usageCount == 1 ? 'y' : 'ies'}. Rename it instead.',
          ),
        ),
      );
      return;
    }

    if (appState.clients.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one client is required')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Client?'),
          content: Text(
            'Delete "$client"? This client is not used by any entries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final removed = context.read<AppState>().removeClient(client);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed ? 'Client deleted' : 'Client could not be deleted',
        ),
      ),
    );
  }

  void showCurrentExcelPeriod() {
    setState(() => excelRange = currentFortnight());
  }

  void showPreviousExcelPeriod() {
    setState(() => excelRange = excelRange.previous);
  }

  void showNextExcelPeriod() {
    setState(() => excelRange = excelRange.next);
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

  Future<void> exportExcel() async {
    final appState = context.read<AppState>();

    final workbook = _excelExportService.buildPayPeriodWorkbook(
      entries: appState.entries,
      settings: appState.settings,
      range: excelRange,
    );

    await FileSaver.instance.saveFile(
      name: workbook.fileName,
      bytes: workbook.bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Excel export saved')));
  }

  Future<void> printTimesheet() async {
    final appState = context.read<AppState>();

    await Printing.layoutPdf(
      name:
          'support_worker_timesheet_${formatDate(excelRange.start)}_${formatDate(excelRange.end)}.pdf',
      onLayout: (format) {
        return _pdfTimesheetService.buildTimesheetPdf(
          entries: appState.entries,
          settings: appState.settings,
          range: excelRange,
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
          title: 'Client Manager',
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
                  FilledButton(onPressed: addClient, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 12),
              for (final client in appState.clients)
                _ClientManagerTile(
                  client: client,
                  usageCount: appState.clientUsageCount(client),
                  canDelete: appState.canRemoveClient(client),
                  onRename: () => renameClient(client),
                  onDelete: () => confirmRemoveClient(client),
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
          title: 'Excel Pay Period Export',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(excelRange.start)} - ${formatDate(excelRange.end)}',
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
                    onPressed: showPreviousExcelPeriod,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: showCurrentExcelPeriod,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Current'),
                  ),
                  OutlinedButton.icon(
                    onPressed: showNextExcelPeriod,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: exportExcel,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export Excel Summary'),
              ),
              const SizedBox(height: 8),
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
    required this.usageCount,
    required this.canDelete,
    required this.onRename,
    required this.onDelete,
  });

  final String client;
  final int usageCount;
  final bool canDelete;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final usageText = usageCount == 0
        ? 'Unused'
        : 'Used in $usageCount entr${usageCount == 1 ? 'y' : 'ies'}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(client),
      subtitle: Text(usageText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename client',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          IconButton(
            tooltip: canDelete
                ? 'Delete unused client'
                : 'Cannot delete a client used by entries',
            icon: const Icon(Icons.delete_outline),
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}
