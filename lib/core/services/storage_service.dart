import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_visit.dart';
import '../models/app_settings.dart';
import '../models/invoice_status.dart';
import '../models/work_entry.dart';

class StoredAppData {
  const StoredAppData({
    required this.settings,
    required this.clients,
    required this.entries,
    this.activeVisit,
    this.invoiceStatuses = const {},
  });

  final AppSettings settings;
  final List<String> clients;
  final List<WorkEntry> entries;
  final ActiveVisit? activeVisit;
  final Map<String, InvoiceStatus> invoiceStatuses;

  factory StoredAppData.defaults() {
    return const StoredAppData(
      settings: AppSettings(),
      clients: ['Client A', 'Client B', 'Client C'],
      entries: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
      'clients': clients,
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'activeVisit': activeVisit?.toJson(),
      'invoiceStatuses': invoiceStatuses.map(
        (key, status) => MapEntry(key, status.name),
      ),
    };
  }

  factory StoredAppData.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    final settings = rawSettings is Map<String, dynamic>
        ? AppSettings.fromJson(rawSettings)
        : const AppSettings();

    final rawClients = json['clients'];
    final clients = rawClients is List
        ? rawClients
              .whereType<String>()
              .where((client) => client.trim().isNotEmpty)
              .toList()
        : <String>[];

    final rawEntries = json['entries'];
    final entries = <WorkEntry>[];

    if (rawEntries is List) {
      for (final rawEntry in rawEntries) {
        if (rawEntry is Map<String, dynamic>) {
          try {
            entries.add(WorkEntry.fromJson(rawEntry));
          } catch (_) {
            // Strip malformed records during load/import.
          }
        }
      }
    }

    final invoiceStatuses = <String, InvoiceStatus>{};
    final rawInvoiceStatuses = json['invoiceStatuses'];

    if (rawInvoiceStatuses is Map) {
      for (final entry in rawInvoiceStatuses.entries) {
        final key = entry.key?.toString() ?? '';
        if (key.trim().isEmpty) continue;

        invoiceStatuses[key] = invoiceStatusFromName(entry.value?.toString());
      }
    }

    ActiveVisit? activeVisit;
    final rawActiveVisit = json['activeVisit'];

    if (rawActiveVisit is Map<String, dynamic>) {
      try {
        activeVisit = ActiveVisit.fromJson(rawActiveVisit);
      } catch (_) {
        activeVisit = null;
      }
    }

    return StoredAppData(
      settings: settings,
      clients: clients.isEmpty ? ['Client A'] : clients,
      entries: entries,
      activeVisit: activeVisit,
      invoiceStatuses: invoiceStatuses,
    );
  }
}

class StorageService {
  static const _dataKey = 'support_worker_log_data_v1';
  static const _backupKey = 'support_worker_log_data_v1_backup';

  Future<StoredAppData> load() async {
    final prefs = await SharedPreferences.getInstance();

    final primary = prefs.getString(_dataKey);
    if (primary != null && primary.trim().isNotEmpty) {
      try {
        return decode(primary);
      } catch (_) {
        // Try backup below.
      }
    }

    final backup = prefs.getString(_backupKey);
    if (backup != null && backup.trim().isNotEmpty) {
      try {
        return decode(backup);
      } catch (_) {
        // Fall through to defaults.
      }
    }

    return StoredAppData.defaults();
  }

  Future<void> save(StoredAppData data) async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_dataKey);
    if (existing != null && existing.trim().isNotEmpty) {
      await prefs.setString(_backupKey, existing);
    }

    await prefs.setString(_dataKey, jsonEncode(data.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dataKey);
    await prefs.remove(_backupKey);
  }

  StoredAppData decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored data root is not an object.');
    }

    return StoredAppData.fromJson(decoded);
  }
}
