import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/work_entry.dart';

class RemovedEntry {
  const RemovedEntry({required this.entry, required this.index});

  final WorkEntry entry;
  final int index;
}

class AppState extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  final List<String> _clients = ['Client A', 'Client B', 'Client C'];

  final List<WorkEntry> _entries = [];

  AppSettings get settings => _settings;
  List<String> get clients => List.unmodifiable(_clients);
  List<WorkEntry> get entries => List.unmodifiable(_entries);

  void updateSettings(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  void addEntry(WorkEntry entry) {
    _entries.insert(0, entry);
    notifyListeners();
  }

  RemovedEntry? deleteEntry(WorkEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return null;

    final removed = _entries.removeAt(index);
    notifyListeners();

    return RemovedEntry(entry: removed, index: index);
  }

  void restoreEntry(RemovedEntry removedEntry) {
    final index = removedEntry.index.clamp(0, _entries.length);
    _entries.insert(index, removedEntry.entry);
    notifyListeners();
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
    notifyListeners();
  }

  void addClient(String client) {
    final trimmed = client.trim();
    if (trimmed.isEmpty) return;
    if (_clients.contains(trimmed)) return;

    _clients.add(trimmed);
    _clients.sort();
    notifyListeners();
  }

  void removeClient(String client) {
    if (_clients.length <= 1) return;

    _clients.remove(client);
    notifyListeners();
  }
}
