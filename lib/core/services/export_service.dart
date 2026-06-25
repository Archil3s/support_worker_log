import 'dart:convert';

import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import '../utils/totals.dart';
import 'storage_service.dart';

class ExportService {
  const ExportService();

  String buildFullSummary({
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer()
      ..writeln('Support Worker Log Summary')
      ..writeln('Generated: ${formatDate(DateTime.now())}')
      ..writeln('')
      ..writeln('Totals')
      ..writeln('Entries: ${sortedEntries.length}')
      ..writeln('Hours: ${totalHours(sortedEntries).toStringAsFixed(2)}')
      ..writeln('Earnings: ${money(totalEarnings(sortedEntries, settings))}')
      ..writeln(
        'Kilometres: ${totalKilometres(sortedEntries).toStringAsFixed(1)}',
      )
      ..writeln('');

    if (sortedEntries.isEmpty) {
      buffer.writeln('No entries recorded.');
      return buffer.toString().trim();
    }

    buffer.writeln('Entries');

    for (final entry in sortedEntries) {
      buffer
        ..writeln('')
        ..writeln('${formatDate(entry.date)} - ${entry.client}')
        ..writeln('Type: ${entry.type.label}')
        ..writeln('Start: ${formatTime(entry.startTime)}')
        ..writeln('Minutes: ${entry.minutes}')
        ..writeln('Hours: ${entry.hours.toStringAsFixed(2)}')
        ..writeln('Earnings: ${money(entry.earnings(settings))}');

      if (entry.type == EntryType.homeVisit) {
        buffer
          ..writeln('KM: ${entry.kilometres.toStringAsFixed(1)}')
          ..writeln('Fuel: ${money(entry.fuelReimbursement(settings))}');
      }

      if (entry.notes.isNotEmpty) {
        buffer.writeln('Notes: ${entry.notes.join(', ')}');
      }
    }

    return buffer.toString().trim();
  }

  String buildJsonBackup({
    required List<WorkEntry> entries,
    required List<String> clients,
    required AppSettings settings,
    List<String> payeClients = const [],
    List<WorkEntry> payeEntries = const [],
  }) {
    final data = StoredAppData(
      settings: settings,
      clients: clients,
      payeClients: payeClients,
      entries: entries,
      payeEntries: payeEntries,
    );

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'backupType': 'support_worker_log',
      'backupVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data.toJson(),
    });
  }

  StoredAppData parseJsonBackup(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be an object.');
    }

    final data = decoded['data'];

    if (data is Map<String, dynamic>) {
      return StoredAppData.fromJson(data);
    }

    return StoredAppData.fromJson(decoded);
  }
}
