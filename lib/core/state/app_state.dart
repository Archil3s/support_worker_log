import 'dart:async';

import 'package:flutter/material.dart';

import '../models/active_visit.dart';
import '../models/app_settings.dart';
import '../models/work_entry.dart';
import '../services/storage_service.dart';
import '../utils/sample_invoice_data.dart';

class RemovedEntry {
  const RemovedEntry({required this.entry, required this.index});

  final WorkEntry entry;
  final int index;
}

class AppState extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  AppSettings _settings = const AppSettings();
  ActiveVisit? _activeVisit;

  final List<String> _clients = [];
  final List<WorkEntry> _entries = [];

  AppSettings get settings => _settings;
  ActiveVisit? get activeVisit => _activeVisit;
  List<String> get clients => List.unmodifiable(_clients);
  List<WorkEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final data = await _storageService.load();
    _replaceInMemory(data);
    notifyListeners();
  }

  Future<void> restoreFromBackup(StoredAppData data) async {
    _replaceInMemory(data);
    await _save();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _storageService.clear();

    _settings = const AppSettings();
    _activeVisit = null;

    _clients
      ..clear()
      ..addAll(['Client A', 'Client B', 'Client C']);

    _entries.clear();

    await _save();
    notifyListeners();
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _persistAndNotify();
  }

  void startActiveVisit(ActiveVisit visit) {
    _activeVisit = visit;
    _persistAndNotify();
  }

  void updateActiveVisit(ActiveVisit visit) {
    if (_activeVisit == null) return;

    _activeVisit = visit;
    _persistAndNotify();
  }

  void cancelActiveVisit() {
    if (_activeVisit == null) return;

    _activeVisit = null;
    _persistAndNotify();
  }

  void completeActiveVisit(WorkEntry entry) {
    _entries.insert(0, entry);
    _activeVisit = null;
    _persistAndNotify();
  }

  void addEntry(WorkEntry entry) {
    _entries.insert(0, entry);
    _persistAndNotify();
  }

  void addEntries(List<WorkEntry> entries) {
    if (entries.isEmpty) return;

    _entries.insertAll(0, entries);
    _persistAndNotify();
  }

  void updateEntry(WorkEntry updatedEntry) {
    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index == -1) return;

    _entries[index] = updatedEntry;
    _persistAndNotify();
  }

  RemovedEntry? deleteEntry(WorkEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return null;

    final removed = _entries.removeAt(index);
    _persistAndNotify();

    return RemovedEntry(entry: removed, index: index);
  }

  void restoreEntry(RemovedEntry removedEntry) {
    final index = _boundedIndex(removedEntry.index);
    _entries.insert(index, removedEntry.entry);
    _persistAndNotify();
  }

  void duplicateEntry(WorkEntry entry) {
    _entries.insert(
      0,
      entry.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        startTime: TimeOfDay.now(),
      ),
    );
    _persistAndNotify();
  }

  bool addClient(String client) {
    final trimmed = client.trim();
    if (trimmed.isEmpty) return false;
    if (_clients.contains(trimmed)) return false;

    _clients.add(trimmed);
    _clients.sort();
    _persistAndNotify();

    return true;
  }

  int clientUsageCount(String client) {
    return _entries.where((entry) => entry.client == client).length;
  }

  bool isClientUsed(String client) {
    return clientUsageCount(client) > 0;
  }

  bool canRemoveClient(String client) {
    if (_clients.length <= 1) return false;
    return !isClientUsed(client);
  }

  bool removeClient(String client) {
    if (!canRemoveClient(client)) return false;

    _clients.remove(client);
    _persistAndNotify();

    return true;
  }

  bool renameClient({required String oldName, required String newName}) {
    final trimmed = newName.trim();

    if (trimmed.isEmpty) return false;
    if (oldName == trimmed) return true;
    if (_clients.contains(trimmed)) return false;

    final clientIndex = _clients.indexOf(oldName);
    if (clientIndex == -1) return false;

    _clients[clientIndex] = trimmed;
    _clients.sort();

    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];

      if (entry.client == oldName) {
        _entries[index] = entry.copyWith(client: trimmed);
      }
    }

    if (_activeVisit?.client == oldName) {
      _activeVisit = _activeVisit!.copyWith(client: trimmed);
    }

    _persistAndNotify();

    return true;
  }

  int replaceEntriesWithInvoiceDataset() {
    final invoiceEntries = sampleInvoiceEntries();

    _entries
      ..clear()
      ..addAll(invoiceEntries);

    _activeVisit = null;

    _clients
      ..clear()
      ..addAll(invoiceEntries.map((entry) => entry.client).toSet())
      ..sort();

    if (_clients.isEmpty) {
      _clients.add('Client A');
    }

    _settings = _settings.copyWith(payPeriodAnchorDate: DateTime(2025, 12, 14));

    _persistAndNotify();

    return invoiceEntries.length;
  }

  void _replaceInMemory(StoredAppData data) {
    _settings = data.settings.weeklyHoursGoal == 20
        ? data.settings.copyWith(weeklyHoursGoal: 10)
        : data.settings;
    _activeVisit = data.activeVisit;

    _clients
      ..clear()
      ..addAll(data.clients.isEmpty ? ['Client A'] : data.clients)
      ..sort();

    final cleanedEntries = _dedupeEntries(data.entries);
    _entries
      ..clear()
      ..addAll(cleanedEntries);
  }

  List<WorkEntry> _dedupeEntries(List<WorkEntry> entries) {
    final seenIds = <String>{};
    final seenContent = <String>{};
    final result = <WorkEntry>[];

    for (final entry in entries) {
      final id = entry.id.trim();

      final contentKey = [
        entry.client,
        entry.type.name,
        entry.date.toIso8601String(),
        entry.startTime.hour,
        entry.startTime.minute,
        entry.minutes,
        entry.kilometres.toStringAsFixed(3),
        entry.notes.join('|'),
      ].join('::');

      if (id.isNotEmpty && seenIds.contains(id)) {
        continue;
      }

      if (seenContent.contains(contentKey)) {
        continue;
      }

      if (id.isNotEmpty) {
        seenIds.add(id);
      }

      seenContent.add(contentKey);
      result.add(entry);
    }

    return result;
  }

  int _boundedIndex(int index) {
    if (index < 0) return 0;
    if (index > _entries.length) return _entries.length;
    return index;
  }

  void _persistAndNotify() {
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() {
    return _storageService.save(
      StoredAppData(
        settings: _settings,
        clients: _clients,
        entries: _entries,
        activeVisit: _activeVisit,
      ),
    );
  }
}
