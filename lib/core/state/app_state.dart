import 'dart:async';

import 'package:flutter/material.dart';

import '../models/active_visit.dart';
import '../models/app_mode.dart';
import '../models/app_settings.dart';
import '../models/general_action.dart';
import '../models/google_export_account_scope.dart';
import '../models/invoice_status.dart';
import '../models/personal_log_entry.dart';
import '../models/work_entry.dart';
import '../services/calendar_export_service.dart';
import '../services/cloud_storage_service.dart';
import '../services/drive_invoice_cycle_sync_service.dart';
import '../services/google_export_account_service.dart';
import '../services/google_drive_service.dart';
import '../services/storage_service.dart';
import '../utils/sample_invoice_data.dart';

class RemovedEntry {
  const RemovedEntry({required this.entry, required this.index});

  final WorkEntry entry;
  final int index;
}

enum CalendarEntryExportResult { created, draftOpened }

class AppState extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final CloudStorageService _cloudStorageService = CloudStorageService();
  final GoogleExportAccountService _googleExportAccountService =
      GoogleExportAccountService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  final DriveInvoiceCycleSyncService _driveInvoiceSyncService =
      DriveInvoiceCycleSyncService();

  AppSettings _settings = const AppSettings();
  AppMode _appMode = AppMode.work;
  ActiveVisit? _activeVisit;

  final List<String> _clients = [];
  final List<WorkEntry> _entries = [];
  final List<GeneralActionItem> _generalActions = [];
  final List<PersonalLogEntry> _personalLogEntries = [];
  final Map<String, InvoiceStatus> _invoiceStatuses = {};
  final Map<String, double> _invoiceBaselineTotals = {};

  StreamSubscription<StoredAppData?>? _cloudDataSubscription;
  String? _cloudDataSubscriptionUserId;
  Timer? _driveInvoiceSyncDebounce;
  Timer? _drivePersonalSyncDebounce;
  bool _driveInvoiceSyncRunning = false;
  bool _driveInvoiceSyncQueued = false;
  bool _drivePersonalSyncRunning = false;
  bool _drivePersonalSyncQueued = false;
  bool _cloudSyncReady = false;
  String? _cloudSyncError;

  AppSettings get settings => _settings;
  AppMode get appMode => _appMode;
  ActiveVisit? get activeVisit => _activeVisit;
  List<String> get clients => List.unmodifiable(_clients);
  List<WorkEntry> get entries => List.unmodifiable(_entries);
  List<GeneralActionItem> get generalActions =>
      List.unmodifiable(_generalActions);
  List<PersonalLogEntry> get personalLogEntries =>
      List.unmodifiable(_personalLogEntries);
  Map<String, InvoiceStatus> get invoiceStatuses =>
      Map.unmodifiable(_invoiceStatuses);
  Map<String, double> get invoiceBaselineTotals =>
      Map.unmodifiable(_invoiceBaselineTotals);

  bool get isSignedIn => _cloudStorageService.isSignedIn;
  bool get cloudSyncReady => _cloudSyncReady;
  String? get cloudSyncError => _cloudSyncError;
  String? get cloudUserId => _cloudStorageService.userId;
  String? get cloudEmail => _cloudStorageService.email;
  String? get googleCalendarAccessToken => _workGoogleCalendarAccessToken;
  String? get googleDriveAccessToken => _workGoogleDriveAccessToken;
  String? get workGoogleAccountEmail =>
      _googleExportAccountService.emailFor(GoogleExportAccountScope.work) ??
      _settings.googleWorkAccountEmail ??
      _cloudStorageService.email;
  String? get personalGoogleAccountEmail =>
      _googleExportAccountService.emailFor(GoogleExportAccountScope.personal) ??
      _settings.googlePersonalAccountEmail;
  bool get workGoogleServicesConnected =>
      _workGoogleCalendarAccessToken != null &&
      _workGoogleDriveAccessToken != null;
  bool get personalGoogleServicesConnected => _googleExportAccountService
      .isConnected(GoogleExportAccountScope.personal);
  bool get googleServicesConnected => workGoogleServicesConnected;

  String? get _workGoogleCalendarAccessToken {
    return _googleExportAccountService.accessTokenFor(
          GoogleExportAccountScope.work,
        ) ??
        _cloudStorageService.googleCalendarAccessToken;
  }

  String? get _workGoogleDriveAccessToken {
    return _googleExportAccountService.accessTokenFor(
          GoogleExportAccountScope.work,
        ) ??
        _cloudStorageService.googleDriveAccessToken;
  }

  String get existingGoogleCalendarAccessToken {
    final token = _workGoogleCalendarAccessToken;

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
    _scheduleDrivePersonalSync();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _cloudStorageService.sendPasswordResetEmail(email);
  }

  Future<String> requireGoogleCalendarAccessToken() {
    final token = _workGoogleCalendarAccessToken;
    if (token != null && token.isNotEmpty) {
      return Future.value(token);
    }

    return _cloudStorageService.requireGoogleCalendarAccessToken();
  }

  Future<String> connectGoogleCalendar({bool forceRefresh = false}) async {
    final connection = await _googleExportAccountService.connect(
      scope: GoogleExportAccountScope.work,
      forceRefresh: forceRefresh,
    );
    _saveGoogleExportEmail(connection);
    notifyListeners();
    _scheduleDriveInvoiceSync();
    return connection.accessToken;
  }

  Future<CalendarEntryExportResult> createPrivateGoogleCalendarEvent(
    WorkEntry entry,
  ) async {
    try {
      var token = _workGoogleCalendarAccessToken;

      if (token == null || token.isEmpty) {
        token = await connectGoogleCalendar();
      }

      await CalendarExportService.createPrivateGoogleCalendarEventForEntry(
        entry,
        accessToken: token,
      );

      return CalendarEntryExportResult.created;
    } catch (error) {
      if (!CalendarExportService.isCalendarPermissionError(error)) {
        final opened =
            await CalendarExportService.openGoogleCalendarDraftForEntry(entry);

        if (opened) return CalendarEntryExportResult.draftOpened;

        rethrow;
      }

      try {
        final refreshedToken = await connectGoogleCalendar(forceRefresh: true);
        await CalendarExportService.createPrivateGoogleCalendarEventForEntry(
          entry,
          accessToken: refreshedToken,
        );

        return CalendarEntryExportResult.created;
      } catch (_) {
        final opened =
            await CalendarExportService.openGoogleCalendarDraftForEntry(entry);

        if (opened) return CalendarEntryExportResult.draftOpened;

        rethrow;
      }
    }
  }

  Future<String> requireGoogleDriveAccessToken({
    bool forceRefresh = false,
    GoogleExportAccountScope scope = GoogleExportAccountScope.work,
  }) async {
    if (scope == GoogleExportAccountScope.work && !forceRefresh) {
      final token = _workGoogleDriveAccessToken;
      if (token != null && token.isNotEmpty) return token;
    }

    if (!forceRefresh) {
      return _googleExportAccountService.requireAccessToken(scope: scope);
    }

    final connection = await _googleExportAccountService.connect(
      scope: scope,
      forceRefresh: true,
    );
    _saveGoogleExportEmail(connection);
    notifyListeners();
    return connection.accessToken;
  }

  Future<String> connectGoogleDrive({
    bool forceRefresh = false,
    GoogleExportAccountScope scope = GoogleExportAccountScope.work,
  }) async {
    final connection = await _googleExportAccountService.connect(
      scope: scope,
      forceRefresh: forceRefresh,
    );
    _saveGoogleExportEmail(connection);
    notifyListeners();
    if (scope == GoogleExportAccountScope.work) {
      _scheduleDriveInvoiceSync();
    } else {
      _scheduleDrivePersonalSync();
    }
    return connection.accessToken;
  }

  Future<String> connectWorkGoogle({bool forceRefresh = false}) {
    return connectGoogleDrive(
      scope: GoogleExportAccountScope.work,
      forceRefresh: forceRefresh,
    );
  }

  Future<String> connectPersonalGoogle({bool forceRefresh = false}) {
    return connectGoogleDrive(
      scope: GoogleExportAccountScope.personal,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> syncPersonalLogsToDrive() async {
    if (_personalLogEntries.isEmpty) return;

    if (!_googleExportAccountService.isConnected(
      GoogleExportAccountScope.personal,
    )) {
      await connectPersonalGoogle();
    }

    await _syncDrivePersonalLogs();
  }

  Future<String> ensurePersonalNotesDriveFolderId() async {
    if (!_googleExportAccountService.isConnected(
      GoogleExportAccountScope.personal,
    )) {
      await connectPersonalGoogle();
    }

    final accessToken = await requireGoogleDriveAccessToken(
      scope: GoogleExportAccountScope.personal,
    );
    final folderId = await _ensurePersonalNotesDriveFolder(accessToken);
    return folderId;
  }

  Future<String> ensurePersonalCategoryDriveFolderId(
    PersonalLogCategory category,
  ) async {
    if (!_googleExportAccountService.isConnected(
      GoogleExportAccountScope.personal,
    )) {
      await connectPersonalGoogle();
    }

    final accessToken = await requireGoogleDriveAccessToken(
      scope: GoogleExportAccountScope.personal,
    );
    final personalFolderId = await _ensurePersonalNotesDriveFolder(accessToken);
    final categoryFolder = await _googleDriveService.findOrCreateFolder(
      accessToken: accessToken,
      parentId: personalFolderId,
      name: _personalCategoryFolderName(category),
    );

    return categoryFolder.id;
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
    _scheduleDrivePersonalSync();
    notifyListeners();
  }

  InvoiceStatus invoiceStatusForKey(String key) {
    return _invoiceStatuses[key] ?? InvoiceStatus.notSubmitted;
  }

  double? invoiceBaselineTotalForKey(String key) {
    return _invoiceBaselineTotals[key];
  }

  void updateInvoiceStatus(
    String key,
    InvoiceStatus status, {
    double? currentTotal,
  }) {
    if (key.trim().isEmpty) return;

    final current = _invoiceStatuses[key] ?? InvoiceStatus.notSubmitted;
    final currentBaseline = _invoiceBaselineTotals[key];
    final baselineChanged =
        currentTotal != null &&
        status != InvoiceStatus.notSubmitted &&
        currentBaseline != currentTotal;

    if (current == status && !baselineChanged) return;

    if (status == InvoiceStatus.notSubmitted) {
      _invoiceStatuses.remove(key);
      _invoiceBaselineTotals.remove(key);
    } else {
      _invoiceStatuses[key] = status;
      if (currentTotal != null) {
        _invoiceBaselineTotals[key] = currentTotal;
      }
    }

    _persistAndNotify();
    _scheduleDriveInvoiceSync();
    _scheduleDrivePersonalSync();
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
    _appMode = AppMode.work;
    _activeVisit = null;

    _clients
      ..clear()
      ..addAll(['Client A', 'Client B', 'Client C']);

    _entries.clear();
    _generalActions.clear();
    _personalLogEntries.clear();
    _invoiceStatuses.clear();
    _invoiceBaselineTotals.clear();

    await _save();
    notifyListeners();
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  void setAppMode(AppMode mode) {
    if (_appMode == mode) return;

    _appMode = mode;
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
    _scheduleDriveInvoiceSync();
  }

  void addEntry(WorkEntry entry) {
    _entries.insert(0, entry);
    _persistAndNotify();
    _scheduleDriveInvoiceSync();
  }

  void addGeneralAction(GeneralActionItem action) {
    final title = action.title.trim();
    if (title.isEmpty) return;

    _generalActions.insert(
      0,
      action.copyWith(
        title: title,
        client: action.scope == GeneralActionScope.client
            ? action.client?.trim()
            : null,
        clearClient: action.scope != GeneralActionScope.client,
      ),
    );
    _persistAndNotify();
  }

  void updateGeneralAction(GeneralActionItem action) {
    final index = _generalActions.indexWhere((item) => item.id == action.id);
    if (index == -1) return;

    _generalActions[index] = action;
    _persistAndNotify();
  }

  void deleteGeneralAction(GeneralActionItem action) {
    _generalActions.removeWhere((item) => item.id == action.id);
    _persistAndNotify();
  }

  void addPersonalLogEntry(PersonalLogEntry entry) {
    final title = entry.title.trim();
    final notes = entry.notes.trim();
    final metric = entry.metric.trim();

    if (title.isEmpty && notes.isEmpty && metric.isEmpty) return;

    _personalLogEntries.insert(
      0,
      entry.copyWith(title: title, notes: notes, metric: metric),
    );
    _persistAndNotify();
    _scheduleDrivePersonalSync();
  }

  void deletePersonalLogEntry(PersonalLogEntry entry) {
    _personalLogEntries.removeWhere((item) => item.id == entry.id);
    _persistAndNotify();
    _scheduleDrivePersonalSync();
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

    final currentEntry = _entries[index];
    final shouldResetCalendar =
        currentEntry.googleCalendarEntered &&
        updatedEntry.googleCalendarEntered &&
        !currentEntry.hasSameCalendarEventDetails(updatedEntry);

    _entries[index] = shouldResetCalendar
        ? updatedEntry.copyWith(googleCalendarEntered: false)
        : updatedEntry;
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

    for (var index = 0; index < _generalActions.length; index++) {
      final action = _generalActions[index];
      if (action.client == oldName) {
        _generalActions[index] = action.copyWith(client: trimmed);
      }
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
      _scheduleDrivePersonalSync();
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
    _scheduleDrivePersonalSync();
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
    _scheduleDrivePersonalSync();
  }

  void _scheduleDriveInvoiceSync() {
    if (!_cloudStorageService.isSignedIn || _entries.isEmpty) return;
    if (_workGoogleDriveAccessToken == null) return;

    _driveInvoiceSyncDebounce?.cancel();
    _driveInvoiceSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_syncDriveInvoicesSafely());
    });
  }

  void _scheduleDrivePersonalSync() {
    if (!_cloudStorageService.isSignedIn || _personalLogEntries.isEmpty) {
      return;
    }
    if (!_googleExportAccountService.isConnected(
      GoogleExportAccountScope.personal,
    )) {
      return;
    }

    _drivePersonalSyncDebounce?.cancel();
    _drivePersonalSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_syncDrivePersonalLogsSafely());
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

    final accessToken = await requireGoogleDriveAccessToken();
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

  Future<void> _syncDrivePersonalLogsSafely() async {
    if (_drivePersonalSyncRunning) {
      _drivePersonalSyncQueued = true;
      return;
    }

    _drivePersonalSyncRunning = true;

    try {
      await _syncDrivePersonalLogs();
    } catch (error) {
      _cloudSyncError = error.toString();
      notifyListeners();
    } finally {
      _drivePersonalSyncRunning = false;

      if (_drivePersonalSyncQueued) {
        _drivePersonalSyncQueued = false;
        _scheduleDrivePersonalSync();
      }
    }
  }

  Future<void> _syncDrivePersonalLogs() async {
    if (!_cloudStorageService.isSignedIn || _personalLogEntries.isEmpty) {
      return;
    }

    final accessToken = await requireGoogleDriveAccessToken(
      scope: GoogleExportAccountScope.personal,
    );
    final personalNotesFolderId = await _ensurePersonalNotesDriveFolder(
      accessToken,
    );

    await _googleDriveService.syncPersonalLogEntries(
      accessToken: accessToken,
      personalNotesFolderId: personalNotesFolderId,
      entries: _personalLogEntries,
    );

    _cloudSyncReady = true;
    _cloudSyncError = null;
    notifyListeners();
  }

  Future<String> _ensurePersonalNotesDriveFolder(String accessToken) async {
    final existing = _settings.personalGoogleDrivePersonalNotesFolderId;
    if (existing != null && existing.isNotEmpty) return existing;

    final rootFolderId = _settings.personalGoogleDriveRootFolderId;
    if (rootFolderId == null || rootFolderId.isEmpty) {
      final folderSetup = await _googleDriveService.createPersonalFolderSetup(
        accessToken: accessToken,
      );
      _settings = folderSetup.applyTo(_settings);
    } else {
      final personalFolder = await _googleDriveService.findOrCreateFolder(
        accessToken: accessToken,
        parentId: rootFolderId,
        name: 'Personal Notes',
      );
      _settings = _settings.copyWith(
        personalGoogleDrivePersonalNotesFolderId: personalFolder.id,
      );
    }

    final data = _currentStoredData();
    await _storageService.save(data);
    if (_cloudStorageService.isSignedIn) {
      await _cloudStorageService.save(data);
    }
    notifyListeners();

    return _settings.personalGoogleDrivePersonalNotesFolderId!;
  }

  void _saveGoogleExportEmail(GoogleExportConnection connection) {
    final email = connection.email?.trim();
    if (email == null || email.isEmpty) return;

    switch (connection.scope) {
      case GoogleExportAccountScope.work:
        final previous = _settings.googleWorkAccountEmail?.trim();
        final accountChanged =
            previous == null ||
            previous.isEmpty ||
            previous.toLowerCase() != email.toLowerCase();
        _settings = _settings.copyWith(
          googleWorkAccountEmail: email,
          clearGoogleDriveFolders: accountChanged,
        );
        break;
      case GoogleExportAccountScope.personal:
        final previous = _settings.googlePersonalAccountEmail?.trim();
        final accountChanged =
            previous == null ||
            previous.isEmpty ||
            previous.toLowerCase() != email.toLowerCase();
        _settings = _settings.copyWith(
          googlePersonalAccountEmail: email,
          clearPersonalGoogleDriveFolders: accountChanged,
        );
        break;
    }

    unawaited(_save());
  }

  String _personalCategoryFolderName(PersonalLogCategory category) {
    switch (category) {
      case PersonalLogCategory.gym:
        return 'Gym';
      case PersonalLogCategory.bodyWeight:
        return 'Body Weight';
      case PersonalLogCategory.health:
        return 'Health';
      case PersonalLogCategory.goal:
        return 'Goals';
      case PersonalLogCategory.note:
        return 'Notes';
    }
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
    _generalActions
      ..clear()
      ..addAll(_dedupeGeneralActions(data.generalActions));
    _personalLogEntries
      ..clear()
      ..addAll(_dedupePersonalLogEntries(data.personalLogEntries));
    _invoiceBaselineTotals
      ..clear()
      ..addAll(data.invoiceBaselineTotals);
    _appMode = data.appMode;
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
    final mergedGeneralActions = _dedupeGeneralActions([
      ...cloudData.generalActions,
      ...localData.generalActions,
    ]);
    final mergedPersonalLogs = _dedupePersonalLogEntries([
      ...cloudData.personalLogEntries,
      ...localData.personalLogEntries,
    ]);

    return StoredAppData(
      settings: cloudData.settings,
      clients: mergedClients.isEmpty ? ['Client A'] : mergedClients,
      entries: mergedEntries,
      activeVisit: cloudData.activeVisit ?? localData.activeVisit,
      generalActions: mergedGeneralActions,
      invoiceStatuses: {
        ...cloudData.invoiceStatuses,
        ...localData.invoiceStatuses,
      },
      invoiceBaselineTotals: {
        ...cloudData.invoiceBaselineTotals,
        ...localData.invoiceBaselineTotals,
      },
      appMode: localData.appMode,
      personalLogEntries: mergedPersonalLogs,
    );
  }

  StoredAppData _currentStoredData() {
    return StoredAppData(
      settings: _settings,
      clients: _clients,
      entries: _entries,
      activeVisit: _activeVisit,
      generalActions: _generalActions,
      invoiceStatuses: _invoiceStatuses,
      invoiceBaselineTotals: _invoiceBaselineTotals,
      appMode: _appMode,
      personalLogEntries: _personalLogEntries,
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

  List<GeneralActionItem> _dedupeGeneralActions(
    List<GeneralActionItem> actions,
  ) {
    final seenIds = <String>{};
    final result = <GeneralActionItem>[];

    for (final action in actions) {
      final id = action.id.trim();
      final title = action.title.trim();
      if (id.isEmpty || title.isEmpty || seenIds.contains(id)) continue;

      seenIds.add(id);
      result.add(action.copyWith(title: title));
    }

    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      final left = a.completedAt ?? a.createdAt;
      final right = b.completedAt ?? b.createdAt;
      return right.compareTo(left);
    });

    return result;
  }

  List<PersonalLogEntry> _dedupePersonalLogEntries(
    List<PersonalLogEntry> entries,
  ) {
    final seenIds = <String>{};
    final result = <PersonalLogEntry>[];

    for (final entry in entries) {
      final id = entry.id.trim();
      if (id.isEmpty || seenIds.contains(id)) continue;

      seenIds.add(id);
      result.add(entry);
    }

    result.sort((a, b) => b.date.compareTo(a.date));

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
    _drivePersonalSyncDebounce?.cancel();
    unawaited(_stopCloudDataSubscription());
    super.dispose();
  }
}
