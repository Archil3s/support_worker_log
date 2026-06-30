import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_visit.dart';
import '../models/app_mode.dart';
import '../models/app_settings.dart';
import '../models/general_action.dart';
import '../models/invoice_status.dart';
import '../models/personal_log_entry.dart';
import '../models/work_entry.dart';
import 'google_drive_service.dart';
import 'local_support_note_service.dart';

class StoredAppData {
  const StoredAppData({
    required this.settings,
    required this.clients,
    required this.entries,
    this.payeClients = const [],
    this.payeEntries = const [],
    this.activeVisit,
    this.generalActions = const [],
    this.invoiceStatuses = const {},
    this.invoiceBaselineTotals = const {},
    this.appMode = AppMode.work,
    this.personalLogEntries = const [],
    this.supportNoteMetas = const {},
    this.driveSupportNoteMetas = const {},
    this.deletedEntryIds = const {},
    this.deletedPayeEntryIds = const {},
  });

  final AppSettings settings;
  final List<String> clients;
  final List<String> payeClients;
  final List<WorkEntry> entries;
  final List<WorkEntry> payeEntries;
  final ActiveVisit? activeVisit;
  final List<GeneralActionItem> generalActions;
  final Map<String, InvoiceStatus> invoiceStatuses;
  final Map<String, double> invoiceBaselineTotals;
  final AppMode appMode;
  final List<PersonalLogEntry> personalLogEntries;
  final Map<String, EntrySupportNoteMeta> supportNoteMetas;
  final Map<String, EntryDriveSupportNoteMeta> driveSupportNoteMetas;
  final Set<String> deletedEntryIds;
  final Set<String> deletedPayeEntryIds;

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
      'payeClients': payeClients,
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'payeEntries': payeEntries.map((entry) => entry.toJson()).toList(),
      'activeVisit': activeVisit?.toJson(),
      'generalActions': generalActions.map((item) => item.toJson()).toList(),
      'invoiceStatuses': invoiceStatuses.map(
        (key, status) => MapEntry(key, status.name),
      ),
      'invoiceBaselineTotals': invoiceBaselineTotals,
      'appMode': appMode.name,
      'personalLogEntries': personalLogEntries
          .map((entry) => entry.toJson())
          .toList(),
      'supportNoteMetas': supportNoteMetas.map(
        (key, meta) => MapEntry(key, meta.toJson()),
      ),
      'driveSupportNoteMetas': driveSupportNoteMetas.map(
        (key, meta) => MapEntry(key, meta.toJson()),
      ),
      'deletedEntryIds': deletedEntryIds.toList()..sort(),
      'deletedPayeEntryIds': deletedPayeEntryIds.toList()..sort(),
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
    final rawPayeClients = json['payeClients'];
    final storedPayeClients = rawPayeClients is List
        ? rawPayeClients
              .whereType<String>()
              .where((client) => client.trim().isNotEmpty)
              .toList()
        : <String>[];

    final rawEntries = json['entries'];
    final entries = <WorkEntry>[];
    final rawPayeEntries = json['payeEntries'];
    final payeEntries = <WorkEntry>[];

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

    if (rawPayeEntries is List) {
      for (final rawEntry in rawPayeEntries) {
        if (rawEntry is Map<String, dynamic>) {
          try {
            payeEntries.add(WorkEntry.fromJson(rawEntry));
          } catch (_) {
            // Strip malformed PAYE records during load/import.
          }
        }
      }
    }
    final payeClients =
        rawPayeClients is List
              ? storedPayeClients
              : payeEntries
                    .map((entry) => entry.client.trim())
                    .where((client) => client.isNotEmpty)
                    .toSet()
                    .toList()
          ..sort();

    final invoiceStatuses = <String, InvoiceStatus>{};
    final rawGeneralActions = json['generalActions'];
    final generalActions = <GeneralActionItem>[];

    if (rawGeneralActions is List) {
      for (final rawItem in rawGeneralActions) {
        if (rawItem is Map<String, dynamic>) {
          try {
            final action = GeneralActionItem.fromJson(rawItem);
            if (action.title.trim().isNotEmpty) {
              generalActions.add(action);
            }
          } catch (_) {
            // Strip malformed records during load/import.
          }
        }
      }
    }

    final rawInvoiceStatuses = json['invoiceStatuses'];
    final rawPersonalLogEntries = json['personalLogEntries'];
    final rawSupportNoteMetas = json['supportNoteMetas'];
    final rawDriveSupportNoteMetas = json['driveSupportNoteMetas'];
    final deletedEntryIds = _entryIdsFromJson(json['deletedEntryIds']);
    final deletedPayeEntryIds = _entryIdsFromJson(json['deletedPayeEntryIds']);
    final personalLogEntries = <PersonalLogEntry>[];
    final supportNoteMetas = <String, EntrySupportNoteMeta>{};
    final driveSupportNoteMetas = <String, EntryDriveSupportNoteMeta>{};

    if (rawPersonalLogEntries is List) {
      for (final rawItem in rawPersonalLogEntries) {
        if (rawItem is Map<String, dynamic>) {
          try {
            final entry = PersonalLogEntry.fromJson(rawItem);
            if (entry.title.trim().isNotEmpty ||
                entry.notes.trim().isNotEmpty) {
              personalLogEntries.add(entry);
            }
          } catch (_) {
            // Strip malformed personal records during load/import.
          }
        }
      }
    }

    if (rawInvoiceStatuses is Map) {
      for (final entry in rawInvoiceStatuses.entries) {
        final key = entry.key?.toString() ?? '';
        if (key.trim().isEmpty) continue;

        invoiceStatuses[key] = invoiceStatusFromName(entry.value?.toString());
      }
    }

    if (rawSupportNoteMetas is Map) {
      for (final entry in rawSupportNoteMetas.entries) {
        final key = entry.key?.toString() ?? '';
        final value = entry.value;
        if (key.trim().isEmpty || value is! Map<String, dynamic>) continue;

        try {
          final meta = EntrySupportNoteMeta.fromJson(value);
          final id = meta.entryId.trim().isEmpty ? key : meta.entryId;
          if (id.trim().isNotEmpty) supportNoteMetas[id] = meta;
        } catch (_) {
          // Strip malformed note metadata during load/import.
        }
      }
    }

    if (rawDriveSupportNoteMetas is Map) {
      for (final entry in rawDriveSupportNoteMetas.entries) {
        final key = entry.key?.toString() ?? '';
        final value = entry.value;
        if (key.trim().isEmpty || value is! Map<String, dynamic>) continue;

        try {
          final meta = EntryDriveSupportNoteMeta.fromJson(value);
          final id = meta.entryId.trim().isEmpty ? key : meta.entryId;
          if (id.trim().isNotEmpty) driveSupportNoteMetas[id] = meta;
        } catch (_) {
          // Strip malformed Drive note metadata during load/import.
        }
      }
    }

    final invoiceBaselineTotals = <String, double>{};
    final rawInvoiceBaselineTotals = json['invoiceBaselineTotals'];

    if (rawInvoiceBaselineTotals is Map) {
      for (final entry in rawInvoiceBaselineTotals.entries) {
        final key = entry.key?.toString() ?? '';
        final value = entry.value;
        if (key.trim().isEmpty || value is! num) continue;

        invoiceBaselineTotals[key] = value.toDouble();
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
      payeClients: payeClients,
      entries: entries,
      payeEntries: payeEntries,
      activeVisit: activeVisit,
      generalActions: generalActions,
      invoiceStatuses: invoiceStatuses,
      invoiceBaselineTotals: invoiceBaselineTotals,
      appMode: appModeFromName(json['appMode'] as String?),
      personalLogEntries: personalLogEntries,
      supportNoteMetas: supportNoteMetas,
      driveSupportNoteMetas: driveSupportNoteMetas,
      deletedEntryIds: deletedEntryIds,
      deletedPayeEntryIds: deletedPayeEntryIds,
    );
  }

  static Set<String> _entryIdsFromJson(Object? value) {
    if (value is! List) return const {};

    return value
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
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
