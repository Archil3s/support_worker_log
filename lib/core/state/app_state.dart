import 'dart:async';

import 'package:flutter/material.dart';

import '../models/active_visit.dart';
import '../models/app_settings.dart';
import '../models/invoice_status.dart';
import '../models/work_entry.dart';
import '../services/cloud_storage_service.dart';
import '../services/drive_invoice_cycle_sync_service.dart';
import '../services/google_drive_service.dart';
import '../services/storage_service.dart';
import '../utils/sample_invoice_data.dart';

class RemovedEntry {
  const RemovedEntry({required this.entry, required this.index});

  final WorkEntry entry;
  final int index;
}

class AppState extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final CloudStorageService _cloudStorageService = CloudStorageService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  final DriveInvoiceCycleSyncService _driveInvoiceSyncService =
      DriveInvoiceCycleSyncService();

  AppSettings _settings = const AppSettings();
  ActiveVisit? _activeVisit;

  final List<String> _clients = [];
  final List<WorkEntry> _entries = [];
  final Map<String, InvoiceStatus> _invoiceStatuses = {};

  StreamSubscription<StoredAppData?>? _cloudDataSubscription;
  String? _cloudDataSubscriptionUserId;
  Timer? _driveInvoiceSyncDebounce;
  bool _driveInvoiceSyncRunning = false;
  bool _driveInvoiceSyncQueued = false;
  bool _cloudSyncReady = false;
  String? _cloudSyncError;

  AppSettings get settings => _settings;
  ActiveVisit? get activeVisit => _activeVisit;
  List<String> get clients => List.unmodifiable(_clients);
  List<WorkEntry> get entries => List.unmodifiable(_entries);
  Map<String, InvoiceStatus> get invoiceStatuses =>
      Map.unmodifiable(_invoiceStatuses);

  bool get isSignedIn => _cloudStorageService.isSignedIn;
  bool get cloudSyncReady => _cloudSyncReady;
  String? get cloudSyncError => _cloudSyncError;
  String? get cloudUserId => _cloudStorageService.userId;
  String? get cloudEmail => _cloudStorageService.email;
  String? get googleCalendarAccessToken =>
      _cloudStorageService.googleCalendarAccessToken;
  String? get googleDriveAccessToken =>
      _cloudStorageService.googleDriveAccessToken;
  bool get googleServicesConnected =>
      _cloudStorageService.googleCalendarAccessToken != null &&
      _cloudStorageService.googleDriveAccessToken != null;

  String get existingGoogleCalendarAccessToken {
    final token = _cloudStorageService.googleCalendarAccessToken;

    if (token == null || token.isEmpty) {
      throw StateError(
        'Google Calendar is not connected. Use Continue with Google or connect Calendar before creating events.',
      );
    }

    return token;
  }

  Future<void> load() async {
    final localData = await _storageService.load();
    _replaceInMemory(localData);

    try {
      await _cloudStorageService.signOutAnonymousUserIfNeeded();

      if (_cloudStorageService.isSignedIn) {
        unawaited(_syncLocalAndCloudSafely());
      } else {
        _cloudSyncReady = false;
        _cloudSyncError = null;
      }
    } catch (error) {
      _cloudSyncReady = false;
      _cloudSyncError = error.toString();
    }

    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _cloudStorageService.signInWithEmailPassword(
      email: email,
      password: password,
    );

    _cloudSyncReady = false;
    _cloudSyncError = null;
    notifyListeners();
    unawaited(_syncLocalAndCloudSafely());
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _cloudStorageService.registerWithEmailPassword(
      email: email,
      password: password,
    );

    _cloudSyncReady = false;
    _cloudSyncError = null;
    notifyListeners();
    unawaited(_syncLocalAndCloudSafely());
  }

  Future<void> signInWithGoogle() async {
    await _cloudStorageService.signInWithGoogle();

    _cloudSyncReady = false;
    _cloudSyncError = null;
    notifyListeners();
    unawaited(_syncLocalAndCloudSafely());
    _scheduleDriveInvoiceSync();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _cloudStorageService.sendPasswordResetEmail(email);
  }

  Future<String> requireGoogleCalendarAccessToken() {
    return _cloudStorageService.requireGoogleCalendarAccessToken();
  }

  Future<String> connectGoogleCalendar() async {
    await _cloudStorageService.connectGoogleServicesForCurrentUser(
      forceRefresh: true,
      allowPopup: true,
    );
    final token = await _cloudStorageService.requireGoogleCalendarAccessToken();
    notifyListeners();
    _scheduleDriveInvoiceSync();
    return token;
  }

  Future<String> requireGoogleDriveAccessToken({bool forceRefresh = false}) {
    return _cloudStorageService.requireGoogleDriveAccessToken(
      forceRefresh: forceRefresh,
    );
  }

  Future<String> connectGoogleDrive({bool forceRefresh = false}) async {
    await _cloudStorageService.connectGoogleServicesForCurrentUser(
      forceRefresh: forceRefresh,
      allowPopup: true,
    );
    final token = await _cloudStorageService.requireGoogleDriveAccessToken();
    notifyListeners();
    _scheduleDriveInvoiceSync();
    return token;
  }

  Future<void> signOut() async {
    await _stopCloudDataSubscription();
    await _cloudStorageService.signOut();
    _cloudSyncReady = false;
    _cloudSyncError = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!_cloudStorageService.isSignedIn) return;

    await _syncLocalAndCloudSafely();
    _scheduleDriveInvoiceSync();
    notifyListeners();
  }

  InvoiceStatus invoiceStatusForKey(String key) {
    return _invoiceStatuses[key] ?? InvoiceStatus.notSubmitted;
  }

  void updateInvoiceStatus(String key, InvoiceStatus status) {
    if (key.trim().isEmpty) return;

    final current = _invoiceStatuses[key] ?? InvoiceStatus.notSubmitted;
    if (current == status) return;

    if (status == InvoiceStatus.notSubmitted) {
      _invoiceStatuses.remove(key);
    } else {
      _invoiceStatuses[key] = status;
    }

    _persistAndNotify();
  }

  Future<void> restoreFromBackup(StoredAppData data) async {
    _replaceInMemory(data);
    await _save();
    _scheduleDriveInvoiceSync();
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
    _invoiceStatuses.clear();

    await _save();
    notifyListeners();
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
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
    _scheduleDriveInvoiceSync();
  }

  void addEntry(WorkEntry entry) {
    _entries.insert(0, entry);
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  void addEntries(List<WorkEntry> entries) {
    if (entries.isEmpty) return;

    _entries.insertAll(0, entries);
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  void updateEntry(WorkEntry updatedEntry) {
    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index == -1) return;

    _entries[index] = updatedEntry;
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  RemovedEntry? deleteEntry(WorkEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return null;

    final removed = _entries.removeAt(index);
    _persistAndNotify();
    _scheduleDriveInvoiceSync();

    return RemovedEntry(entry: removed, index: index);
  }

  void restoreEntry(RemovedEntry removedEntry) {
    final index = _boundedIndex(removedEntry.index);
    _entries.insert(index, removedEntry.entry);
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  void duplicateEntry(WorkEntry entry) {
    _entries.insert(
      0,
      entry.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        startTime: TimeOfDay.now(),
        googleCalendarEntered: false,
      ),
    );
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
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
    _scheduleDriveInvoiceSync();

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
    _scheduleDriveInvoiceSync();

    return invoiceEntries.length;
  }

  Future<void> _syncLocalAndCloud() async {
    final localData = _currentStoredData();
    final cloudData = await _cloudStorageService.load();

    if (cloudData == null) {
      await _cloudStorageService.save(localData);
      _cloudSyncReady = true;
      _cloudSyncError = null;
      _startCloudDataSubscription();
      _scheduleDriveInvoiceSync();
      return;
    }

    final mergedData = _mergeStoredData(
      localData: localData,
      cloudData: cloudData,
    );

    _replaceInMemory(mergedData);

    await _storageService.save(mergedData);
    await _cloudStorageService.save(mergedData);

    _cloudSyncReady = true;
    _cloudSyncError = null;
    _startCloudDataSubscription();
    _scheduleDriveInvoiceSync();
  }

  Future<void> _syncLocalAndCloudSafely() async {
    try {
      await _syncLocalAndCloud();
    } catch (error) {
      _cloudSyncReady = false;
      _cloudSyncError = error.toString();
    }

    notifyListeners();
  }

  void _startCloudDataSubscription() {
    final userId = _cloudStorageService.userId;

    if (userId == null || userId.isEmpty) {
      unawaited(_stopCloudDataSubscription());
      return;
    }

    if (_cloudDataSubscriptionUserId == userId &&
        _cloudDataSubscription != null) {
      return;
    }

    unawaited(_stopCloudDataSubscription());
    _cloudDataSubscriptionUserId = userId;
    _cloudDataSubscription = _cloudStorageService.watch().listen(
      (cloudData) {
        unawaited(_applyCloudData(cloudData));
      },
      onError: (Object error) {
        _cloudSyncReady = false;
        _cloudSyncError = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _stopCloudDataSubscription() async {
    _cloudDataSubscriptionUserId = null;
    await _cloudDataSubscription?.cancel();
    _cloudDataSubscription = null;
  }

  Future<void> _applyCloudData(StoredAppData? cloudData) async {
    if (cloudData == null) return;

    _replaceInMemory(cloudData);
    await _storageService.save(cloudData);

    _cloudSyncReady = true;
    _cloudSyncError = null;
    notifyListeners();
    _scheduleDriveInvoiceSync();
  }

  void _scheduleDriveInvoiceSync() {
    if (!_cloudStorageService.isSignedIn || _entries.isEmpty) return;
    if (_cloudStorageService.googleDriveAccessToken == null) return;

    _driveInvoiceSyncDebounce?.cancel();
    _driveInvoiceSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_syncDriveInvoicesSafely());
    });
  }

  Future<void> _syncDriveInvoicesSafely() async {
    if (_driveInvoiceSyncRunning) {
      _driveInvoiceSyncQueued = true;
      return;
    }

    _driveInvoiceSyncRunning = true;

    try {
      await _syncDriveInvoices();
    } catch (error) {
      _cloudSyncError = error.toString();
      notifyListeners();
    } finally {
      _driveInvoiceSyncRunning = false;

      if (_driveInvoiceSyncQueued) {
        _driveInvoiceSyncQueued = false;
        _scheduleDriveInvoiceSync();
      }
    }
  }

  Future<void> _syncDriveInvoices() async {
    if (!_cloudStorageService.isSignedIn || _entries.isEmpty) return;

    final accessToken = await _cloudStorageService
        .requireGoogleDriveAccessToken();
    var syncSettings = _settings;
    var clientNotesFolderId = syncSettings.googleDriveClientNotesFolderId;
    var invoicesFolderId = syncSettings.googleDriveInvoicesFolderId;

    if (clientNotesFolderId == null ||
        clientNotesFolderId.isEmpty ||
        invoicesFolderId == null ||
        invoicesFolderId.isEmpty) {
      final folderSetup = await _googleDriveService.createFolderSetup(
        accessToken: accessToken,
      );

      _settings = folderSetup.applyTo(_settings);
      syncSettings = _settings;
      clientNotesFolderId = syncSettings.googleDriveClientNotesFolderId;
      invoicesFolderId = syncSettings.googleDriveInvoicesFolderId;

      final data = _currentStoredData();
      await _storageService.save(data);
      await _cloudStorageService.save(data);
      notifyListeners();
    }

    if (clientNotesFolderId == null ||
        clientNotesFolderId.isEmpty ||
        invoicesFolderId == null ||
        invoicesFolderId.isEmpty) {
      return;
    }

    await _driveInvoiceSyncService.syncInvoiceCycles(
      accessToken: accessToken,
      clientNotesFolderId: clientNotesFolderId,
      invoicesFolderId: invoicesFolderId,
      entries: _entries,
      settings: syncSettings,
    );

    _cloudSyncReady = true;
    _cloudSyncError = null;
    notifyListeners();
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

    _invoiceStatuses
      ..clear()
      ..addAll(data.invoiceStatuses);
  }

  StoredAppData _mergeStoredData({
    required StoredAppData localData,
    required StoredAppData cloudData,
  }) {
    final mergedClients = {
      ...cloudData.clients,
      ...localData.clients,
    }.where((client) => client.trim().isNotEmpty).toList()..sort();

    final mergedEntries = _dedupeEntries([
      ...cloudData.entries,
      ...localData.entries,
    ]);

    return StoredAppData(
      settings: cloudData.settings,
      clients: mergedClients.isEmpty ? ['Client A'] : mergedClients,
      entries: mergedEntries,
      activeVisit: cloudData.activeVisit ?? localData.activeVisit,
      invoiceStatuses: {
        ...cloudData.invoiceStatuses,
        ...localData.invoiceStatuses,
      },
    );
  }

  StoredAppData _currentStoredData() {
    return StoredAppData(
      settings: _settings,
      clients: _clients,
      entries: _entries,
      activeVisit: _activeVisit,
      invoiceStatuses: _invoiceStatuses,
    );
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

  Future<void> _save() async {
    final data = _currentStoredData();

    await _storageService.save(data);

    if (!_cloudStorageService.isSignedIn) return;

    try {
      await _cloudStorageService.save(data);
      _cloudSyncReady = true;
      _cloudSyncError = null;
    } catch (error) {
      _cloudSyncReady = false;
      _cloudSyncError = error.toString();
    }
  }

  @override
  void dispose() {
    _driveInvoiceSyncDebounce?.cancel();
    unawaited(_stopCloudDataSubscription());
    super.dispose();
  }
}
