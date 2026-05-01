import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/work_entry.dart';
import '../services/storage_service.dart';

class RemovedEntry {
  const RemovedEntry({required this.entry, required this.index});

  final WorkEntry entry;
  final int index;
}

class AppState extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  AppSettings _settings = const AppSettings();

  final List<String> _clients = [];
  final List<WorkEntry> _entries = [];

  AppSettings get settings => _settings;
  List<String> get clients => List.unmodifiable(_clients);
  List<WorkEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final data = await _storageService.load();

    _settings = data.settings;

    _clients
      ..clear()
      ..addAll(data.clients);

    _entries
      ..clear()
      ..addAll(data.entries);

    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _storageService.clear();

    _settings = const AppSettings();

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

  void addEntry(WorkEntry entry) {
    _entries.insert(0, entry);
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

  void addClient(String client) {
    final trimmed = client.trim();
    if (trimmed.isEmpty) return;
    if (_clients.contains(trimmed)) return;

    _clients.add(trimmed);
    _clients.sort();
    _persistAndNotify();
  }

  void removeClient(String client) {
    if (_clients.length <= 1) return;

    _clients.remove(client);
    _persistAndNotify();
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
      StoredAppData(settings: _settings, clients: _clients, entries: _entries),
    );
  }
}
